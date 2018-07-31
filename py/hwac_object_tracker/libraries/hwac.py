from pynq import Xlnk
from pynq import MMIO
import numpy as np
import math
import cv2
import struct
import os.path
from collections import deque

RESET_REG           = 0
PHY_ADDR_REG        = 4
START_REG           = 8
DONE_REG            = 12
INST_DATA0_REG      = 20
INST_DATA1_REG      = 24
INST_DATA2_REG      = 28
INST_ADDR_REG       = 32
CTRL_STATE_REG      = 48
MEM_RD_STATE_REG    = 52
MEM_WR_STATE_REG    = 56
LOOP_STATE_REG      = 60
CP_HEADER0_REG      = 64
CP_HEADER1_REG      = 68
RD_STATE0_REG       = 72
RD_STATE1_REG       = 76
RD_STATE2_REG       = 80
WR_STATE0_REG       = 84
WR_STATE1_REG       = 88
WR_STATE2_REG       = 92
LINE_BUFF_COL_CNT   = 96
LINE_BUFF_ROW_CNT   = 100
CACHE_WRTR_COL_CNT  = 104
CACHE_WRTR_ROW_CNT  = 108
CONV_STREAM_STATE   = 112
CONV_RX_TOT_PIX     = 116
CTRL_CP_COUNT0_REG  = 120
CTRL_CP_COUNT1_REG  = 124
CTRL_CP_IF_REG      = 128
BB_XY_REG           = 132
BB_WH_REG           = 136
BB_ADDR_REG         = 140

CMD_END  = 0
CMD_LD_W = 1
CMD_LD_D = 2
CMD_SV_D = 3
CMD_FULL = 4
CMD_LAYER_END = 5
WEIGHTS_BUF_IDX = 0


FC_FLT_CNT = 500
    
class FPGA:
    initdone = False
    memalloc = False
    xlnk = None
    ctrl = None
    mem = None
    im_wh_q = None
    bb_list = list()
    cmdidx = 0

    anchors = [0.57273, 0.677385, 1.87446, 2.06253, 3.33843, 5.47434, 7.88282, 3.52778, 9.77052, 9.16828]

    def __init__(self, xlnk):
        self.xlnk = xlnk
        self.ctrl = MMIO(0x40000000, 0x1000)
        self.im_wh_q = deque()
        self.bb_list = list()
        try:
            self.mem = xlnk.cma_array(shape=(0x800000,4), dtype=np.float16)
            self.memalloc = True
        except:
            print("CMA array allocation failed (64MB)")
            print("Please call xlnk.xlnk_reset() or Restart notebook")
            xlnk.xlnk_reset()
            

        
        
    def configure(self, weight_file, padding_file):
        if (self.memalloc == False):
            return False
        
        self.ctrl.write(PHY_ADDR_REG, self.mem.physical_address)
        self.ctrl.write(RESET_REG, 1)
        self.ctrl.write(RESET_REG, 0)
        rd = self.ctrl.read(PHY_ADDR_REG)
        if (rd != self.mem.physical_address):
            xlnk.xlnk_reset()
            print("Error: Memory mapped IO failed")
            return False
        
        if (os.path.isfile(weight_file)):
            W = np.load(weight_file)
            woff = 0
            for i in range(len(W)):
                self.mem[woff:(woff + W[i].shape[0]),:] = W[i]
                woff += W[i].shape[0]
        else:
            print("Error: Weight file not found")
            self.xlnk.xlnk_reset()
            return False
        
        if (os.path.isfile(padding_file)):
            W = np.load(padding_file)
            membase = 7 << 20
            self.mem[membase: (membase | W.shape[0]), :] = W
        else:
            print("Error: Padding file not found")
            self.xlnk.xlnk_reset()
            return False
        
        membase = 4 << 20
        self.mem[membase:(membase | 106496), 3] = np.zeros((106496), dtype=np.float16) 
        
        self.setLayer1()
        self.inst_layer_end()
        self.setLayer2()
        self.setLayer3()
        self.setLayer4()
        self.setLayer5()
        self.setLayer6()
        self.setLayer7()
        self.setLayer8()
        self.setLayer9()
        self.inst_end()
        print("FPGA configured for TinyYOLO v2 | %d classes" % (FC_FLT_CNT//5-5))
        return True
        

    def Sigmoid(self, x):
         return 1.0/(1.0+np.exp(-x))
        
    def WaitBoundingBox(self):
        d0=self.ctrl.read(BB_ADDR_REG)
        while(((d0>>11) & 0x1) == 0):
            d0=self.ctrl.read(BB_ADDR_REG)

        d1 = self.ctrl.read(BB_XY_REG)
        d2 = self.ctrl.read(BB_WH_REG)
        return d0, d1, d2
    

    def PostProcessBB(self, d0, d1, d2):
        addr = d0 & 0xff
        achorset = (d0>>8) & 0x7

        (x, y) = struct.unpack('e'*2, struct.pack("<I", d1))
        (w, h) = struct.unpack('e'*2, struct.pack("<I", d2))
        
        x = (addr%13 + self.Sigmoid(x))/13
        y = (addr//13 + self.Sigmoid(y))/13
        w = np.exp(w) * self.anchors[2*achorset] / 13
        h = np.exp(h) * self.anchors[2*achorset+1] / 13

        (imw, imh, nw, nh) = self.im_wh_q.popleft()

        if (imw >= imh):
            y = (y - (416 - nh)/832.0) / (nh/416)
            h = h * 416 / nh
        else:
            nw = imw*416/imh
            x = (x - (416 - nw)/832.0) / (nw/416)
            w = w * 416 / nw

        left = int((x - w/2.0)*imw)
        right= int((x + w/2.0)*imw)
        top  = int((y - h/2.0)*imh)
        bot  = int((y + h/2.0)*imh)
#         print("Left: %d, Right: %d, Top: %d, Bottom: %d" % (left, right, top, bot))
        self.bb_list.append([left, right, top, bot])
        

    def PadImg(self, img):
        p = np.full((256,416), 0.5, dtype=np.float16)
        p[(256-234)//2+1:(256+234)//2+1,:] = img
        return np.float16(p)

    def readImage(self, name):
        img = cv2.imread(name)
        imw = img.shape[1]
        imh = img.shape[0]
        if (imw > imh):
            w = 416
            h = int(416*imh/imw)
            if (h > 256):
                h = 256
        else:
            h = 256
            w = int(256*imw/imh)
            if (w > 416):
                w = 416
        resized = cv2.resize(img, (w, h))/255.0
        img = np.empty((256, 416, 3), dtype=np.float16)
        h0 = (256-h)//2
        h1 = (256+h)//2
        img[h0:h1,:,:] = np.float16(resized)
        img[0:h0,:,:] = np.full((h0,416,3), 0.5, dtype=np.float16)
        img[h1:256,:,:] = np.full(((256-h1),416,3), 0.5, dtype=np.float16)
        self.mem[4194304:4300800, 0] = np.reshape(img[:,:,2], (106496))
        self.mem[4194304:4300800, 1] = np.reshape(img[:,:,1], (106496))
        self.mem[4194304:4300800, 2] = np.reshape(img[:,:,0], (106496))  
        self.im_wh_q.append((imw, imh, w, h))      


    def startswBB(self):
        self.ctrl.write(START_REG, 3)
        
    def start(self):
        self.ctrl.write(START_REG, 1)
    
    def stop(self):
        self.ctrl.write(START_REG, 0)
        
    def waitMemWrite(self):
        while ((self.ctrl.read(DONE_REG) & 0x1) == 0):
            None
            
    def waitFistLayer(self):
        while ((self.ctrl.read(DONE_REG) & 0x2) == 0):
            None
            
    def reset(self):
        self.ctrl.write(RESET_REG, 1)
        self.ctrl.write(RESET_REG, 0)

    
# CNN configuration

    def inst_ld_weights(self, addr, width, height, conv_size, pool_stride, padding, save_results, prev_weights, padvalue):
        data = CMD_LD_W | (WEIGHTS_BUF_IDX << 3) | (width << 6) | (height << 14) | (conv_size << 22) | (pool_stride << 24) | (padding << 26) | ((addr & 0x3) << 30)
        self.ctrl.write(INST_DATA0_REG, data)
        tot = width * height
        data = ((addr >> 2) & 0x1fffff)  | ((tot & 0x7ff) << 21)
        self.ctrl.write(INST_DATA1_REG, data)
        data = ((tot >> 11) & 0x7) | (save_results << 3) | (prev_weights << 4) | (padvalue << 6)
        self.ctrl.write(INST_DATA2_REG, data)
        self.ctrl.write(INST_ADDR_REG, self.cmdidx)
        self.cmdidx+=1   

    def inst_ld_data(self, buf_idx, addr, offset, width, height):
        data = CMD_LD_D | (buf_idx << 3) | (width << 6) | (height << 14) | ((addr & 0x3) << 30)
        self.ctrl.write(INST_DATA0_REG, data)
        data = ((addr >> 2) & 0x1fffff) | ((offset & 0x7ff) << 21)
        self.ctrl.write(INST_DATA1_REG, data)
        data = (offset >> 11)   
        self.ctrl.write(INST_DATA2_REG, data)
        self.ctrl.write(INST_ADDR_REG, self.cmdidx)
        self.cmdidx+=1   

    def inst_sv_data(self, buf_idx, addr, offset, width, height):
        data = CMD_SV_D | (buf_idx << 3) | (width << 6) | (height << 14) | ((addr & 0x3) << 30)
        self.ctrl.write(INST_DATA0_REG, data)
        data = ((addr >> 2) & 0x1fffff) | ((offset & 0x7ff) << 21)
        self.ctrl.write(INST_DATA1_REG, data)
        data = (offset >> 11)   
        self.ctrl.write(INST_DATA2_REG, data)
        self.ctrl.write(INST_ADDR_REG, self.cmdidx)
        self.cmdidx+=1  

    def inst_full(self, weights_addr, rd_w, rd_h, conv_size, pool_stride, rd_buf, wr_buf, c, n, out_bb, padval, wr_offset):
        padding = 0xf if (conv_size == 3) else 0
        data = CMD_FULL | (rd_buf << 3) | (rd_w << 6) | (rd_h << 14) | (conv_size << 22) | (pool_stride << 24) | (padding << 26) | ((weights_addr & 0x3) << 30)
        self.ctrl.write(INST_DATA0_REG, data)
        tot = rd_w * rd_h
        data = ((weights_addr >> 2) & 0x1fffff) | ((tot & 0x7ff) << 21)
        self.ctrl.write(INST_DATA1_REG, data)
        data = ((tot >> 11) & 0x7) | (padval << 6)
        self.ctrl.write(INST_DATA2_REG, data)
        self.ctrl.write(INST_ADDR_REG, self.cmdidx)
        self.cmdidx+=1    
        if (pool_stride == 2):
            wr_w = rd_w // 2
            tot = tot // 4
        else:
            wr_w = rd_w
        data = CMD_FULL | (wr_buf << 3) | (wr_w << 6) | (wr_offset << 14) 
        self.ctrl.write(INST_DATA0_REG, data)
        data = (math.ceil(c/4) << 1) | (math.ceil(n/4) << 11) | ((tot & 0x7ff) << 21)
        self.ctrl.write(INST_DATA1_REG, data)
        data = ((tot >> 11) & 0x7) | (out_bb << 5)
        self.ctrl.write(INST_DATA2_REG, data)
        self.ctrl.write(INST_ADDR_REG, self.cmdidx)
        self.cmdidx+=1    
        
    def inst_layer_end(self):
        self.ctrl.write(INST_DATA0_REG, CMD_LAYER_END)
        self.ctrl.write(INST_DATA1_REG, 0)
        self.ctrl.write(INST_DATA2_REG, 0)
        self.ctrl.write(INST_ADDR_REG, self.cmdidx)
        self.cmdidx+=1  
        
    def inst_end(self):
        self.ctrl.write(INST_DATA0_REG, CMD_END)
        self.ctrl.write(INST_DATA1_REG, 0)
        self.ctrl.write(INST_DATA2_REG, 0)
        self.ctrl.write(INST_ADDR_REG, self.cmdidx)
        self.cmdidx+=1  
        
    def setLayer9(self):
#         print("Layer9 13x13 512->%d 1 0" % FC_FLT_CNT)
        self.inst_full(2753544, 13, 13, 1, 0, 6, 5, 512, FC_FLT_CNT, 1, 0, 0)

    def setLayer8(self):
#         print("Layer8 13x13 1024->512 3 0")
        self.inst_full(1573640, 13, 13, 3, 0, 5, 6, 1024, 512, 0, 0, 0)
        
    def setLayer7(self):
#         print("Layer7 13x13 512->1024 3 0")
        self.inst_full(393480, 13, 13, 3, 0, 6, 5, 512, 1024, 0, 0, 0)
        
    def setLayer6(self):
#         print("Layer6 13x13 256->512 3 1")
        self.inst_full(98312, 13, 13, 3, 1, 5, 6, 256, 512, 0, 0, 0)
        
    def setLayer5(self):
#         print("Layer5 26x26 128->256 3 2")
        self.inst_full(24456, 26, 26, 3, 2, 6, 5, 128, 256, 0, 0, 0)
        
    def setLayer4(self):
#         print("Layer4 52x32 64->128 3 2")
        self.inst_full(5960, 52, 52, 3, 2, 7, 6, 64, 128, 0, 0, 0)
        
    def setLayer3(self):
#         print("Layer3 104x64 32->64 3 2")
        self.inst_full(1320, 104, 64, 3, 2, 6, 7, 32, 64, 0, 1, 52*10)
        
    def setLayer2(self):
#         print("Layer2 208x128 16->32 3 2")
        self.inst_ld_weights(152, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 0, 208, 53, 128)
        self.inst_ld_weights(188, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 26624, 208, 53, 128)
        self.inst_ld_weights(224, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 53248, 208, 53, 128)
        self.inst_ld_weights(260, 53, 128, 3, 2, 7, 1, 0, 1)
        self.inst_ld_data(5, 79872, 208, 53, 128)
        self.inst_sv_data(6, 0, 104, 26, 64)
        self.inst_ld_weights(152, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 51, 208, 54, 128)
        self.inst_ld_weights(188, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26675, 208, 54, 128)
        self.inst_ld_weights(224, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53299, 208, 54, 128)
        self.inst_ld_weights(260, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79923, 208, 54, 128)
        self.inst_sv_data(6, 26, 104, 26, 64)
        self.inst_ld_weights(152, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 103, 208, 54, 128)
        self.inst_ld_weights(188, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26727, 208, 54, 128)
        self.inst_ld_weights(224, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53351, 208, 54, 128)
        self.inst_ld_weights(260, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79975, 208, 54, 128)
        self.inst_sv_data(6, 52, 104, 26, 64)
        self.inst_ld_weights(152, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 155, 208, 53, 128)
        self.inst_ld_weights(188, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 26779, 208, 53, 128)
        self.inst_ld_weights(224, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 53403, 208, 53, 128)
        self.inst_ld_weights(260, 53, 128, 3, 2, 11, 1, 0, 1)
        self.inst_ld_data(5, 80027, 208, 53, 128)
        self.inst_sv_data(6, 78, 104, 26, 64)
        self.inst_ld_weights(298, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 0, 208, 53, 128)
        self.inst_ld_weights(334, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 26624, 208, 53, 128)
        self.inst_ld_weights(370, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 53248, 208, 53, 128)
        self.inst_ld_weights(406, 53, 128, 3, 2, 7, 1, 0, 1)
        self.inst_ld_data(5, 79872, 208, 53, 128)
        self.inst_sv_data(6, 6656, 104, 26, 64)
        self.inst_ld_weights(298, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 51, 208, 54, 128)
        self.inst_ld_weights(334, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26675, 208, 54, 128)
        self.inst_ld_weights(370, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53299, 208, 54, 128)
        self.inst_ld_weights(406, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79923, 208, 54, 128)
        self.inst_sv_data(6, 6682, 104, 26, 64)
        self.inst_ld_weights(298, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 103, 208, 54, 128)
        self.inst_ld_weights(334, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26727, 208, 54, 128)
        self.inst_ld_weights(370, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53351, 208, 54, 128)
        self.inst_ld_weights(406, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79975, 208, 54, 128)
        self.inst_sv_data(6, 6708, 104, 26, 64)
        self.inst_ld_weights(298, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 155, 208, 53, 128)
        self.inst_ld_weights(334, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 26779, 208, 53, 128)
        self.inst_ld_weights(370, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 53403, 208, 53, 128)
        self.inst_ld_weights(406, 53, 128, 3, 2, 11, 1, 0, 1)
        self.inst_ld_data(5, 80027, 208, 53, 128)
        self.inst_sv_data(6, 6734, 104, 26, 64)
        self.inst_ld_weights(444, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 0, 208, 53, 128)
        self.inst_ld_weights(480, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 26624, 208, 53, 128)
        self.inst_ld_weights(516, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 53248, 208, 53, 128)
        self.inst_ld_weights(552, 53, 128, 3, 2, 7, 1, 0, 1)
        self.inst_ld_data(5, 79872, 208, 53, 128)
        self.inst_sv_data(6, 13312, 104, 26, 64)
        self.inst_ld_weights(444, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 51, 208, 54, 128)
        self.inst_ld_weights(480, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26675, 208, 54, 128)
        self.inst_ld_weights(516, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53299, 208, 54, 128)
        self.inst_ld_weights(552, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79923, 208, 54, 128)
        self.inst_sv_data(6, 13338, 104, 26, 64)
        self.inst_ld_weights(444, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 103, 208, 54, 128)
        self.inst_ld_weights(480, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26727, 208, 54, 128)
        self.inst_ld_weights(516, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53351, 208, 54, 128)
        self.inst_ld_weights(552, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79975, 208, 54, 128)
        self.inst_sv_data(6, 13364, 104, 26, 64)
        self.inst_ld_weights(444, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 155, 208, 53, 128)
        self.inst_ld_weights(480, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 26779, 208, 53, 128)
        self.inst_ld_weights(516, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 53403, 208, 53, 128)
        self.inst_ld_weights(552, 53, 128, 3, 2, 11, 1, 0, 1)
        self.inst_ld_data(5, 80027, 208, 53, 128)
        self.inst_sv_data(6, 13390, 104, 26, 64)
        self.inst_ld_weights(590, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 0, 208, 53, 128)
        self.inst_ld_weights(626, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 26624, 208, 53, 128)
        self.inst_ld_weights(662, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 53248, 208, 53, 128)
        self.inst_ld_weights(698, 53, 128, 3, 2, 7, 1, 0, 1)
        self.inst_ld_data(5, 79872, 208, 53, 128)
        self.inst_sv_data(6, 19968, 104, 26, 64)
        self.inst_ld_weights(590, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 51, 208, 54, 128)
        self.inst_ld_weights(626, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26675, 208, 54, 128)
        self.inst_ld_weights(662, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53299, 208, 54, 128)
        self.inst_ld_weights(698, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79923, 208, 54, 128)
        self.inst_sv_data(6, 19994, 104, 26, 64)
        self.inst_ld_weights(590, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 103, 208, 54, 128)
        self.inst_ld_weights(626, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26727, 208, 54, 128)
        self.inst_ld_weights(662, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53351, 208, 54, 128)
        self.inst_ld_weights(698, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79975, 208, 54, 128)
        self.inst_sv_data(6, 20020, 104, 26, 64)
        self.inst_ld_weights(590, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 155, 208, 53, 128)
        self.inst_ld_weights(626, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 26779, 208, 53, 128)
        self.inst_ld_weights(662, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 53403, 208, 53, 128)
        self.inst_ld_weights(698, 53, 128, 3, 2, 11, 1, 0, 1)
        self.inst_ld_data(5, 80027, 208, 53, 128)
        self.inst_sv_data(6, 20046, 104, 26, 64)
        self.inst_ld_weights(736, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 0, 208, 53, 128)
        self.inst_ld_weights(772, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 26624, 208, 53, 128)
        self.inst_ld_weights(808, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 53248, 208, 53, 128)
        self.inst_ld_weights(844, 53, 128, 3, 2, 7, 1, 0, 1)
        self.inst_ld_data(5, 79872, 208, 53, 128)
        self.inst_sv_data(6, 26624, 104, 26, 64)
        self.inst_ld_weights(736, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 51, 208, 54, 128)
        self.inst_ld_weights(772, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26675, 208, 54, 128)
        self.inst_ld_weights(808, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53299, 208, 54, 128)
        self.inst_ld_weights(844, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79923, 208, 54, 128)
        self.inst_sv_data(6, 26650, 104, 26, 64)
        self.inst_ld_weights(736, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 103, 208, 54, 128)
        self.inst_ld_weights(772, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26727, 208, 54, 128)
        self.inst_ld_weights(808, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53351, 208, 54, 128)
        self.inst_ld_weights(844, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79975, 208, 54, 128)
        self.inst_sv_data(6, 26676, 104, 26, 64)
        self.inst_ld_weights(736, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 155, 208, 53, 128)
        self.inst_ld_weights(772, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 26779, 208, 53, 128)
        self.inst_ld_weights(808, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 53403, 208, 53, 128)
        self.inst_ld_weights(844, 53, 128, 3, 2, 11, 1, 0, 1)
        self.inst_ld_data(5, 80027, 208, 53, 128)
        self.inst_sv_data(6, 26702, 104, 26, 64)
        self.inst_ld_weights(882, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 0, 208, 53, 128)
        self.inst_ld_weights(918, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 26624, 208, 53, 128)
        self.inst_ld_weights(954, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 53248, 208, 53, 128)
        self.inst_ld_weights(990, 53, 128, 3, 2, 7, 1, 0, 1)
        self.inst_ld_data(5, 79872, 208, 53, 128)
        self.inst_sv_data(6, 33280, 104, 26, 64)
        self.inst_ld_weights(882, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 51, 208, 54, 128)
        self.inst_ld_weights(918, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26675, 208, 54, 128)
        self.inst_ld_weights(954, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53299, 208, 54, 128)
        self.inst_ld_weights(990, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79923, 208, 54, 128)
        self.inst_sv_data(6, 33306, 104, 26, 64)
        self.inst_ld_weights(882, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 103, 208, 54, 128)
        self.inst_ld_weights(918, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26727, 208, 54, 128)
        self.inst_ld_weights(954, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53351, 208, 54, 128)
        self.inst_ld_weights(990, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79975, 208, 54, 128)
        self.inst_sv_data(6, 33332, 104, 26, 64)
        self.inst_ld_weights(882, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 155, 208, 53, 128)
        self.inst_ld_weights(918, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 26779, 208, 53, 128)
        self.inst_ld_weights(954, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 53403, 208, 53, 128)
        self.inst_ld_weights(990, 53, 128, 3, 2, 11, 1, 0, 1)
        self.inst_ld_data(5, 80027, 208, 53, 128)
        self.inst_sv_data(6, 33358, 104, 26, 64)
        self.inst_ld_weights(1028, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 0, 208, 53, 128)
        self.inst_ld_weights(1064, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 26624, 208, 53, 128)
        self.inst_ld_weights(1100, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 53248, 208, 53, 128)
        self.inst_ld_weights(1136, 53, 128, 3, 2, 7, 1, 0, 1)
        self.inst_ld_data(5, 79872, 208, 53, 128)
        self.inst_sv_data(6, 39936, 104, 26, 64)
        self.inst_ld_weights(1028, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 51, 208, 54, 128)
        self.inst_ld_weights(1064, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26675, 208, 54, 128)
        self.inst_ld_weights(1100, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53299, 208, 54, 128)
        self.inst_ld_weights(1136, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79923, 208, 54, 128)
        self.inst_sv_data(6, 39962, 104, 26, 64)
        self.inst_ld_weights(1028, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 103, 208, 54, 128)
        self.inst_ld_weights(1064, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26727, 208, 54, 128)
        self.inst_ld_weights(1100, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53351, 208, 54, 128)
        self.inst_ld_weights(1136, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79975, 208, 54, 128)
        self.inst_sv_data(6, 39988, 104, 26, 64)
        self.inst_ld_weights(1028, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 155, 208, 53, 128)
        self.inst_ld_weights(1064, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 26779, 208, 53, 128)
        self.inst_ld_weights(1100, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 53403, 208, 53, 128)
        self.inst_ld_weights(1136, 53, 128, 3, 2, 11, 1, 0, 1)
        self.inst_ld_data(5, 80027, 208, 53, 128)
        self.inst_sv_data(6, 40014, 104, 26, 64)
        self.inst_ld_weights(1174, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 0, 208, 53, 128)
        self.inst_ld_weights(1210, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 26624, 208, 53, 128)
        self.inst_ld_weights(1246, 53, 128, 3, 2, 7, 0, 0, 1)
        self.inst_ld_data(5, 53248, 208, 53, 128)
        self.inst_ld_weights(1282, 53, 128, 3, 2, 7, 1, 0, 1)
        self.inst_ld_data(5, 79872, 208, 53, 128)
        self.inst_sv_data(6, 46592, 104, 26, 64)
        self.inst_ld_weights(1174, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 51, 208, 54, 128)
        self.inst_ld_weights(1210, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26675, 208, 54, 128)
        self.inst_ld_weights(1246, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53299, 208, 54, 128)
        self.inst_ld_weights(1282, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79923, 208, 54, 128)
        self.inst_sv_data(6, 46618, 104, 26, 64)
        self.inst_ld_weights(1174, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 103, 208, 54, 128)
        self.inst_ld_weights(1210, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 26727, 208, 54, 128)
        self.inst_ld_weights(1246, 54, 128, 3, 2, 3, 0, 0, 1)
        self.inst_ld_data(5, 53351, 208, 54, 128)
        self.inst_ld_weights(1282, 54, 128, 3, 2, 3, 1, 0, 1)
        self.inst_ld_data(5, 79975, 208, 54, 128)
        self.inst_sv_data(6, 46644, 104, 26, 64)
        self.inst_ld_weights(1174, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 155, 208, 53, 128)
        self.inst_ld_weights(1210, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 26779, 208, 53, 128)
        self.inst_ld_weights(1246, 53, 128, 3, 2, 11, 0, 0, 1)
        self.inst_ld_data(5, 53403, 208, 53, 128)
        self.inst_ld_weights(1282, 53, 128, 3, 2, 11, 1, 0, 1)
        self.inst_ld_data(5, 80027, 208, 53, 128)
        self.inst_sv_data(6, 46670, 104, 26, 64)
        
    def setLayer1(self):
#         print("Layer1 416x256 3->16 3 2")
        self.inst_ld_weights(0, 53, 129, 3, 2, 5, 1, 0, 1)
        self.inst_ld_data(4, 0, 416, 53, 129)
        self.inst_sv_data(5, 0, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 51, 416, 54, 129)
        self.inst_sv_data(5, 26, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 103, 416, 54, 129)
        self.inst_sv_data(5, 52, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 155, 416, 54, 129)
        self.inst_sv_data(5, 78, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 207, 416, 54, 129)
        self.inst_sv_data(5, 104, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 259, 416, 54, 129)
        self.inst_sv_data(5, 130, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 311, 416, 54, 129)
        self.inst_sv_data(5, 156, 208, 26, 64)
        self.inst_ld_weights(0, 53, 129, 3, 2, 9, 1, 1, 1)
        self.inst_ld_data(4, 363, 416, 53, 129)
        self.inst_sv_data(5, 182, 208, 26, 64)
        self.inst_ld_weights(0, 53, 129, 3, 2, 6, 1, 1, 1)
        self.inst_ld_data(4, 52832, 416, 53, 129)
        self.inst_sv_data(5, 13312, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52883, 416, 54, 129)
        self.inst_sv_data(5, 13338, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52935, 416, 54, 129)
        self.inst_sv_data(5, 13364, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52987, 416, 54, 129)
        self.inst_sv_data(5, 13390, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53039, 416, 54, 129)
        self.inst_sv_data(5, 13416, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53091, 416, 54, 129)
        self.inst_sv_data(5, 13442, 208, 26, 64)
        self.inst_ld_weights(0, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53143, 416, 54, 129)
        self.inst_sv_data(5, 13468, 208, 26, 64)
        self.inst_ld_weights(0, 53, 129, 3, 2, 10, 1, 1, 1)
        self.inst_ld_data(4, 53195, 416, 53, 129)
        self.inst_sv_data(5, 13494, 208, 26, 64)
        self.inst_ld_weights(38, 53, 129, 3, 2, 5, 1, 0, 1)
        self.inst_ld_data(4, 0, 416, 53, 129)
        self.inst_sv_data(5, 26624, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 51, 416, 54, 129)
        self.inst_sv_data(5, 26650, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 103, 416, 54, 129)
        self.inst_sv_data(5, 26676, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 155, 416, 54, 129)
        self.inst_sv_data(5, 26702, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 207, 416, 54, 129)
        self.inst_sv_data(5, 26728, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 259, 416, 54, 129)
        self.inst_sv_data(5, 26754, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 311, 416, 54, 129)
        self.inst_sv_data(5, 26780, 208, 26, 64)
        self.inst_ld_weights(38, 53, 129, 3, 2, 9, 1, 1, 1)
        self.inst_ld_data(4, 363, 416, 53, 129)
        self.inst_sv_data(5, 26806, 208, 26, 64)
        self.inst_ld_weights(38, 53, 129, 3, 2, 6, 1, 1, 1)
        self.inst_ld_data(4, 52832, 416, 53, 129)
        self.inst_sv_data(5, 39936, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52883, 416, 54, 129)
        self.inst_sv_data(5, 39962, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52935, 416, 54, 129)
        self.inst_sv_data(5, 39988, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52987, 416, 54, 129)
        self.inst_sv_data(5, 40014, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53039, 416, 54, 129)
        self.inst_sv_data(5, 40040, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53091, 416, 54, 129)
        self.inst_sv_data(5, 40066, 208, 26, 64)
        self.inst_ld_weights(38, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53143, 416, 54, 129)
        self.inst_sv_data(5, 40092, 208, 26, 64)
        self.inst_ld_weights(38, 53, 129, 3, 2, 10, 1, 1, 1)
        self.inst_ld_data(4, 53195, 416, 53, 129)
        self.inst_sv_data(5, 40118, 208, 26, 64)
        self.inst_ld_weights(76, 53, 129, 3, 2, 5, 1, 0, 1)
        self.inst_ld_data(4, 0, 416, 53, 129)
        self.inst_sv_data(5, 53248, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 51, 416, 54, 129)
        self.inst_sv_data(5, 53274, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 103, 416, 54, 129)
        self.inst_sv_data(5, 53300, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 155, 416, 54, 129)
        self.inst_sv_data(5, 53326, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 207, 416, 54, 129)
        self.inst_sv_data(5, 53352, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 259, 416, 54, 129)
        self.inst_sv_data(5, 53378, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 311, 416, 54, 129)
        self.inst_sv_data(5, 53404, 208, 26, 64)
        self.inst_ld_weights(76, 53, 129, 3, 2, 9, 1, 1, 1)
        self.inst_ld_data(4, 363, 416, 53, 129)
        self.inst_sv_data(5, 53430, 208, 26, 64)
        self.inst_ld_weights(76, 53, 129, 3, 2, 6, 1, 1, 1)
        self.inst_ld_data(4, 52832, 416, 53, 129)
        self.inst_sv_data(5, 66560, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52883, 416, 54, 129)
        self.inst_sv_data(5, 66586, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52935, 416, 54, 129)
        self.inst_sv_data(5, 66612, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52987, 416, 54, 129)
        self.inst_sv_data(5, 66638, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53039, 416, 54, 129)
        self.inst_sv_data(5, 66664, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53091, 416, 54, 129)
        self.inst_sv_data(5, 66690, 208, 26, 64)
        self.inst_ld_weights(76, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53143, 416, 54, 129)
        self.inst_sv_data(5, 66716, 208, 26, 64)
        self.inst_ld_weights(76, 53, 129, 3, 2, 10, 1, 1, 1)
        self.inst_ld_data(4, 53195, 416, 53, 129)
        self.inst_sv_data(5, 66742, 208, 26, 64)
        self.inst_ld_weights(114, 53, 129, 3, 2, 5, 1, 0, 1)
        self.inst_ld_data(4, 0, 416, 53, 129)
        self.inst_sv_data(5, 79872, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 51, 416, 54, 129)
        self.inst_sv_data(5, 79898, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 103, 416, 54, 129)
        self.inst_sv_data(5, 79924, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 155, 416, 54, 129)
        self.inst_sv_data(5, 79950, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 207, 416, 54, 129)
        self.inst_sv_data(5, 79976, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 259, 416, 54, 129)
        self.inst_sv_data(5, 80002, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 1, 1, 1, 1)
        self.inst_ld_data(4, 311, 416, 54, 129)
        self.inst_sv_data(5, 80028, 208, 26, 64)
        self.inst_ld_weights(114, 53, 129, 3, 2, 9, 1, 1, 1)
        self.inst_ld_data(4, 363, 416, 53, 129)
        self.inst_sv_data(5, 80054, 208, 26, 64)
        self.inst_ld_weights(114, 53, 129, 3, 2, 6, 1, 1, 1)
        self.inst_ld_data(4, 52832, 416, 53, 129)
        self.inst_sv_data(5, 93184, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52883, 416, 54, 129)
        self.inst_sv_data(5, 93210, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52935, 416, 54, 129)
        self.inst_sv_data(5, 93236, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 52987, 416, 54, 129)
        self.inst_sv_data(5, 93262, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53039, 416, 54, 129)
        self.inst_sv_data(5, 93288, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53091, 416, 54, 129)
        self.inst_sv_data(5, 93314, 208, 26, 64)
        self.inst_ld_weights(114, 54, 129, 3, 2, 2, 1, 1, 1)
        self.inst_ld_data(4, 53143, 416, 54, 129)
        self.inst_sv_data(5, 93340, 208, 26, 64)
        self.inst_ld_weights(114, 53, 129, 3, 2, 10, 1, 1, 1)
        self.inst_ld_data(4, 53195, 416, 53, 129)
        self.inst_sv_data(5, 93366, 208, 26, 64)
        
    def debugPrint(self):
        data = self.ctrl.read(CTRL_STATE_REG)
        print("rd_buf_rx_state: %d, rd_buf_tx_state: %d, wr_buf_rx_state: %d, wr_buf_tx_state: %d, inst_state: %d, controller_state: %d" % ((data & 0xf), ((data >> 4) & 0xf), ((data >> 8) & 0xf), ((data >> 12) & 0xf), ((data >> 16) & 0xf), ((data >> 24) & 0xff)))
        data = self.ctrl.read(MEM_RD_STATE_REG)
        print("rd_if_tx_state: %d, rd_if_rx_state: %d, fifo_count: %d, arready: %d, arvalid: %d, rready: %d, rvalid: %d" % ((data & 0xf), ((data >> 4) & 0xf), ((data >> 8) & 0xf), ((data >> 12) & 0x1), ((data >> 13) & 0x1), ((data >> 14) & 0x1), ((data >> 15) & 0x1)))
        data = self.ctrl.read(MEM_WR_STATE_REG)
        print("wr_if_tx_state: %d, wr_if_rx_state: %d, awready: %d, awvalid: %d, wready: %d, wvalid: %d, bready: %d, bvalid: %d, fifo_full: %d, fifo_empty: %d, prog_full_1665: %d, rx_tready: %d, rx_tvalid: %d, idle: %d" % ((data & 0xff), ((data >> 8) & 0xff), ((data >> 16) & 0x1), ((data >> 17) & 0x1), ((data >> 18) & 0x1), ((data >> 19) & 0x1), ((data >> 20) & 0x1), ((data >> 21) & 0x1), ((data >> 24) & 0x1), ((data >> 25) & 0x1), ((data >> 26) & 0x1), ((data >> 27) & 0x1), ((data >> 28) & 0x1), ((data >> 31) & 0x1)))
        
        data = self.ctrl.read(LOOP_STATE_REG)
        print("ch4: %d, flt4: %d, wr_valid: %d, wr_ack: %d, rd_valid: %d, rd_ack: %d" % ((data & 0x3ff), ((data >> 10) & 0x3ff), ((data >> 20) & 0x1), ((data >> 21) & 0x1), ((data >> 22) & 0x1), ((data >> 23) & 0x1)))
        data0 = self.ctrl.read(CP_HEADER0_REG)
        data1 = self.ctrl.read(CP_HEADER1_REG)  #wrong in bit file
        print("width: %d, height: %d, total: %d, conv_size: %d, pool_stride: %d, padding: 0x%x, save_result: %d, pad_value: %d, activation: %d" % ((data0 & 0xff), ((data0 >> 8) & 0xff), ((data0 >> 16) & 0x3fff), ((data0 >> 30) & 0x3), (data1 & 0x3), ((data1 >> 2) & 0xf), ((data1 >> 6) & 0x1), ((data1 >> 7) & 0x1), ((data1 >> 8) & 0x1)))
        
        data0 = self.ctrl.read(RD_STATE0_REG)
        data1 = self.ctrl.read(RD_STATE1_REG)  
        data2 = self.ctrl.read(RD_STATE2_REG)  
        print("rd_buf: %d, rd_addr: %d, rd_width: %d, rd_count: %d, rd_offset: %d, rd_header_only: %d, rd_valid: %d, rd_ack: %d" % ((data0 & 0x7), ((data0 >> 3) & 0xfffff), (((data0 >> 23) & 0x1ff) | ((data1 & 0x7ff) << 9)) , ((data1 >> 11) & 0xfffff), (((data1 >> 31) & 0x1) | ((data2 & 0x7ffff) << 1)), ((data2 >> 19) & 0x1), ((data2 >> 20) & 0x1), ((data2 >> 21) & 0x1)))
        data0 = self.ctrl.read(WR_STATE0_REG)
        data1 = self.ctrl.read(WR_STATE1_REG)  
        data2 = self.ctrl.read(WR_STATE2_REG)  
        print("wr_buf: %d, wr_addr: %d, wr_width: %d, wr_count: %d, wr_offset: %d, wr_bb: %d, wr_valid: %d, wr_ack: %d" % ((data0 & 0x7), ((data0 >> 3) & 0xfffff), (((data0 >> 23) & 0x1ff) | ((data1 & 0x7ff) << 9)) , ((data1 >> 11) & 0xfffff), (((data1 >> 31) & 0x1) | ((data2 & 0x7ffff) << 1)), ((data2 >> 19) & 0x1), ((data2 >> 20) & 0x1), ((data2 >> 21) & 0x1)))
        print("Line Buff Col Count : %x, Line Buff Row Count : %x" % (self.ctrl.read(LINE_BUFF_COL_CNT), self.ctrl.read(LINE_BUFF_ROW_CNT)))
        print("Cache writer Col Count : %x, Cache writer Row Count : %x" % (self.ctrl.read(CACHE_WRTR_COL_CNT), self.ctrl.read(CACHE_WRTR_ROW_CNT)))
        print("Conv Stream State : %x" % self.ctrl.read(CONV_STREAM_STATE))
        print("Conv RX Total Pixels : %d" % self.ctrl.read(CONV_RX_TOT_PIX))
        data = self.ctrl.read(CTRL_CP_COUNT0_REG)
        print("Ctrl->CP : %d, %d" % ((data & 0xffff), ((data >> 16) & 0xffff)))
        data = self.ctrl.read(CTRL_CP_COUNT1_REG)
        print("CP->Ctrl : %d, %d" % ((data & 0xffff), ((data >> 16) & 0xffff)))
        data = self.ctrl.read(CTRL_CP_IF_REG)
        print("CP<->Ctrl if: %x" % data)