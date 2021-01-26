/* ------------------------------------------------ *
 * Title       : MCP4725 Simulation                 *
 * Project     : MCP4725 DAC Interface              *
 * ------------------------------------------------ *
 * File        : sim.v                              *
 * Author      : Yigit Suoglu                       *
 * Last Edit   : 25/01/2021                         *
 * ------------------------------------------------ *
 * Description : Module for simulating MCP4725 DAC  *
 *               Interface                          *
 * ------------------------------------------------ */
`timescale 1ns / 1ps
//`include "Sources/mcp4725.v"

module tb();
  reg clk,rst,enable,writeToMem,readFromMem,clk_2x100kHz,clk_2x400kHz,clk_2x1_7MHz,clk_2x3_4MHz;
  wire SCL, SDA;
  reg [11:0] data_i;
  wire [11:0] data_reg;
  wire [1:0] mode_reg;
  reg [1:0] i2cSpeed;

  pulldown(SDA);

  always #5 clk = ~clk;
  always #150 clk_2x3_4MHz = ~clk_2x3_4MHz;
  always #300  clk_2x1_7MHz = ~clk_2x1_7MHz;
  always #625 clk_2x400kHz = ~clk_2x400kHz;
  always #2500  clk_2x100kHz = ~clk_2x100kHz;

  mcp4725 uut(clk, rst, SCL, SDA, data_i, data_reg, enable, 2'b00,mode_reg, writeToMem, readFromMem, i2cSpeed, 1'b0,clk_2x100kHz,clk_2x400kHz,clk_2x1_7MHz,clk_2x3_4MHz);

  initial
    begin
      $dumpfile("sim.vcd");
      $dumpvars(0, clk);
      $dumpvars(1, rst);
      $dumpvars(2, clk_2x100kHz);
      $dumpvars(3, clk_2x400kHz);
      $dumpvars(4, clk_2x1_7MHz);
      $dumpvars(5, clk_2x3_4MHz);
      $dumpvars(6, enable);
      $dumpvars(7, writeToMem);
      $dumpvars(8, readFromMem);
      $dumpvars(9, SCL);
      $dumpvars(10, SDA);
      $dumpvars(11, data_i);
      $dumpvars(12, data_reg);
      $dumpvars(13, mode_reg);
      $dumpvars(14, i2cSpeed);
      #6000000
      $finish;
    end
  initial
    begin
      clk = 0;
      clk_2x100kHz = 0;
      clk_2x1_7MHz = 0;
      clk_2x3_4MHz = 0;
      clk_2x400kHz = 0;
      rst = 0;
      enable = 1;
      i2cSpeed = 2'b0;
      data_i = 12'd0;
      readFromMem = 0;
      writeToMem = 0;
      #13
      rst = 1;
      #10
      rst = 0;
      #40
      data_i = 12'hfff;
    end
endmodule
