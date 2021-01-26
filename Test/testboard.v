/* ------------------------------------------------ *
 * Title       : MCP4725 Interface Testboard        *
 * Project     : MCP4725 DAC Interface              *
 * ------------------------------------------------ *
 * File        : testboard.v                        *
 * Author      : Yigit Suoglu                       *
 * Last Edit   : 25/01/2021                         *
 * ------------------------------------------------ *
 * Description : Module for testing MCP4725 DAC     *
 *               Interface                          *
 * ------------------------------------------------ */
//`include "Sources/mcp4725.v"
//`include "Test/btn_debouncer.v"
//`include "Test/ssd_util.v"

module testboard(
  input clk,
  input rst,
  input [12:0] sw,
  input [1:0] i2cSpeed,
  output [12:0] led,
  input update, //SW13
  input btnU, //readMem
  input btnL, //writeMem
  inout SDA, //JC4
  output SCL, //JC3
  output A0,  //JC2
  output [6:0] seg,
  output [3:0] an);

  wire readMem, writeMem;
  wire [11:0] val;
  wire [1:0] mode_reg;
  wire clk_2x100kHz,clk_2x400kHz,clk_2x1_7MHz,clk_2x3_4MHz;

  assign A0 = 1'd0;
  assign led = {mode_reg[0],val};

  debouncer dbU(clk, rst, btnU, readMem);
  debouncer dbL(clk, rst, btnL, writeMem);
  ssdController4 ssdCntrl(clk, rst, 4'b0111, , val[11:8], val[7:4], val[3:0], seg, an);
  
  mcp4725 uut(clk,rst,SCL,SDA,sw[11:0],val,update,{1'd0, sw[12]},mode_reg,writeMem,readMem,i2cSpeed,A0,clk_2x100kHz,clk_2x400kHz,clk_2x1_7MHz,clk_2x3_4MHz);

  clkGen100MHz_6_25MHz clkGen0(clk,rst,clk_2x3_4MHz);
  clkGenclk6_25MHz_3_12MHz clkGen1(clk_2x3_4MHz,rst,clk_2x1_7MHz);
  clkGen3_12MHz_781kHz clkGen2(clk_2x1_7MHz,rst,clk_2x400kHz);
  clkGen_781kHz_195kHz clkGen3(clk_2x400kHz,rst,clk_2x100kHz);

endmodule//testboard
