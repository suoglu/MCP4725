/* ------------------------------------------------ *
 * Title       : MCP4725 DAC Interface v1           *
 * Project     : MCP4725 DAC Interface              *
 * ------------------------------------------------ *
 * File        : mcp4725.v                          *
 * Author      : Yigit Suoglu                       *
 * Last Edit   : //2021                         *
 * ------------------------------------------------ *
 * Description : Interface module for MCP4725 DAC   *
 * ------------------------------------------------ *
 * Revisions                                        *
 *     v1      : Inital version                     *
 * ------------------------------------------------ */

module mcp4725(
  input clk,
  input rst,
  //I2C interface
  output SCL,
  inout SDA,
  //Data interface
  input [11:0] data_i,
  output reg [11:0] data_reg,
  input enable,
  input [1:0] mode_i,
  output [1:0] mode_reg,
  //Memory control
  input writeToMem,
  input readFromMem,
  //Configurations
  input [1:0] i2cSpeed,
  input A0,
  //External clock signals, unused ones can be left unconnected
  input clk_2x100kHz,
  input clk_2x400kHz,
  input clk_2x1_7MHz,
  input clk_2x3_4MHz);
  localparam ADDRESSI2Cmid = 4'b0001;

  wire [7:0] devAddres;
  wire readNwrite;
  wire dataUpdate;

  assign devAddres = {{2{~i2cSpeed[1]}},ADDRESSI2Cmid, A0, readNwrite};
endmodule//mcp4725
