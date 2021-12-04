/* ------------------------------------------------ *
 * Title       : MCP4725 DAC Interface v1           *
 * Project     : MCP4725 DAC Interface              *
 * ------------------------------------------------ *
 * File        : mcp4725.v                          *
 * Author      : Yigit Suoglu                       *
 * Last Edit   : 04/12/2021                         *
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
  input SDA_i,
  output SDA_o,
  output SDA_t,
  //Data interface
  input [11:0] data_i,
  output reg [11:0] data_reg,
  input enable,
  input [1:0] mode_i,
  output reg [1:0] mode_reg,
  //Memory control
  input writeToMem,
  input readFromMem,
  //Configurations
  input [1:0] i2cSpeed,
  input A0,
  //External clock signals, unused ones can be left unconnected
  input clk_2x100kHz, //Required for Memory writing?
  input clk_2x400kHz,
  input clk_2x1_7MHz,
  input clk_2x3_4MHz);

  localparam ADDRESSI2Cmid = 4'b0001;
  //I2C states
  localparam I2CREADY = 3'b000,
             I2CSTART = 3'b001,
             I2CADDRS = 3'b011,
             I2CWRITE = 3'b110,
         I2CWRITE_ACK = 3'b010,
              I2CREAD = 3'b111,
          I2CREAD_ACK = 3'b101,
              I2CSTOP = 3'b100;
  reg [2:0] i2cState;
  //I2C internal signals
  reg [7:0] SDA_i_buff, SDA_o_buff, SDA_i_source;
  reg i2c_double_clk; //Used to shifting and sampling
  reg i2c_clk; //Low: Shift High: Sample
  wire SDA_Write;
  wire SDA_Claim;
  wire SDA_Shift_State, SDA_Update_State;
  reg SDA_d;
  reg i2c_double_clk_d, SCL_d;

  wire i2c_double_clk_posedge =  i2c_double_clk & ~i2c_double_clk_d;
  wire i2c_double_clk_negedge = ~i2c_double_clk &  i2c_double_clk_d;
  wire SCL_posedge =  SCL & ~SCL_d;

  //Counters
  reg [2:0] i2cBitCounter;
  wire i2cBitCounterDONE;
  reg [2:0] i2cByteCounter;
  reg i2cByteCounterDONE;
  //States
  localparam IDLE = 2'b00,
             UPDATE = 2'b01,
             WRITEMEM = 2'b11,
             READMEM = 2'b10;
  reg [1:0] state;

  //Decode I2C states
  wire i2cinREADY = (i2cState == I2CREADY);
  wire i2cinSTART = (i2cState == I2CSTART);
  wire i2cinADDRS = (i2cState == I2CADDRS);
  wire i2cinWRITE = (i2cState == I2CWRITE);
  wire i2cinWRITEACK = (i2cState == I2CWRITE_ACK);
  wire i2cinREAD = (i2cState == I2CREAD);
  wire i2cinREADACK = (i2cState == I2CREAD_ACK);
  wire i2cinSTOP = (i2cState == I2CSTOP);
  wire i2cFinished = i2cinSTOP & SCL;
  wire i2cinACK = i2cinREADACK | i2cinWRITEACK;

  //Decode states
  wire inIDLE = (state == IDLE);
  wire inUPDATE = (state == UPDATE);
  wire inWRITEMEM = (state == WRITEMEM);
  wire inREADMEM = (state == READMEM);
  wire inMEMop = inWRITEMEM | inREADMEM;
  wire readNwrite = inREADMEM;

  //Get i2c address
  wire [7:0] devAddres = {{2{~i2cSpeed[1]}},ADDRESSI2Cmid, A0, readNwrite}; //Device i2c address

  //Data update condition
  wire dataUpdate = enable & ((data_i != data_reg) | (mode_i != mode_reg));

  assign SCL = (i2cinREADY) ? 1'b1 : i2c_clk;

  //Handle i2c_double_clk
  always@* begin
    if(inMEMop)
      i2c_double_clk = clk_2x100kHz;
    else case(i2cSpeed)
      2'd0: i2c_double_clk = clk_2x100kHz;
      2'd1: i2c_double_clk = clk_2x400kHz;
      2'd2: i2c_double_clk = clk_2x1_7MHz;
      2'd3: i2c_double_clk = clk_2x3_4MHz;
    endcase
  end 

  //I2C state transactions
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      i2cState <= I2CREADY;
    end else if (i2c_double_clk_negedge)
      case(i2cState)
        I2CREADY     : i2cState <= (~inIDLE & i2c_clk) ? I2CSTART : i2cState;
        I2CSTART     : i2cState <= (~SCL) ? I2CADDRS : i2cState;
        I2CADDRS     : i2cState <= (~SCL & i2cBitCounterDONE) ? I2CWRITE_ACK : i2cState;
        I2CWRITE_ACK : i2cState <= (~SCL) ? ((~SDA_d & ~i2cByteCounterDONE) ? ((~readNwrite) ? I2CWRITE : I2CREAD): I2CSTOP) : i2cState;
        I2CWRITE     : i2cState <= (~SCL & i2cBitCounterDONE) ? I2CWRITE_ACK : i2cState;
        I2CREAD      : i2cState <= (~SCL & i2cBitCounterDONE) ? I2CREAD_ACK : i2cState;
        I2CREAD_ACK  : i2cState <= (~SCL) ? ((i2cByteCounterDONE) ? I2CSTOP : I2CREAD) : i2cState;
        I2CSTOP      : i2cState <= (SCL) ? I2CREADY : i2cState;
      endcase
  end

  //I2C data line handling
  assign SDA = (SDA_Claim) ? SDA_Write : SDA_i;
  assign SDA_o = SDA;
  assign SDA_t = ~SDA_Claim;
  assign SDA_Claim = i2cinSTART | i2cinADDRS | i2cinWRITE | i2cinREADACK | i2cinSTOP;
  assign SDA_Write = (i2cinSTART | i2cinREADACK | i2cinSTOP) ? 1'd0 : SDA_i_buff[7];

  //Delays
  always@(posedge clk)  begin
    i2c_double_clk_d <= i2c_double_clk;
    SDA_d <= i2c_double_clk_negedge ? SDA : SDA_d;
  end

  //I2C byte counter
  always@(posedge i2cinACK or posedge i2cinSTART) begin
    if(i2cinSTART) begin
      i2cByteCounter <= 3'd0;
    end else if(i2cinACK) begin
      i2cByteCounter <= i2cByteCounter + 3'd1;
    end
  end
  always@*
    case(state)
      UPDATE   : i2cByteCounterDONE = (i2cByteCounter == 3'd3);
      WRITEMEM : i2cByteCounterDONE = (i2cByteCounter == 3'd4);
      READMEM  : i2cByteCounterDONE = (i2cByteCounter == 3'd6);
      default  : i2cByteCounterDONE = 1;
    endcase

  //I2C bit counter
  assign i2cBitCounterDONE = ~|i2cBitCounter;
  always@(posedge clk) 
    case(i2cState)
      I2CADDRS : i2cBitCounter <= i2cBitCounter + {2'd0, SCL_posedge};
      I2CWRITE : i2cBitCounter <= i2cBitCounter + {2'd0, SCL_posedge};
      I2CREAD  : i2cBitCounter <= i2cBitCounter + {2'd0, SCL_posedge};
      default  : i2cBitCounter <= 3'd0;
    endcase

  //SDA_i handle
  always@*
    case(i2cByteCounter)
      3'd0: SDA_i_source = devAddres;
      3'd1:
        case(state)
          UPDATE   : SDA_i_source = {2'd0, mode_reg, data_reg[11:8]};
          WRITEMEM : SDA_i_source = {3'b011, 2'b11, mode_reg, mode_reg[0]};
          default  : SDA_i_source = 8'd0;
        endcase
      3'd2:
        case(state)
          UPDATE   : SDA_i_source = data_reg[7:0];
          WRITEMEM : SDA_i_source = data_reg[11:4];
          default  : SDA_i_source = 8'd0;
        endcase
      3'd3:
        case(state)
          WRITEMEM : SDA_i_source = {data_reg[3:0], {4{data_reg[0]}}};
          default  : SDA_i_source = 8'd0;
        endcase
      default:
        SDA_i_source = 8'd0;
    endcase

  always@(posedge clk) begin
    if(i2c_double_clk_negedge) begin
      if(SDA_Update_State)
        SDA_i_buff <= SDA_i_source;
      else if(SDA_Shift_State & ~SCL & |i2cBitCounter)
        SDA_i_buff <= {SDA_i_buff << 1};
    end
  end
  assign SDA_Update_State = i2cinSTART | i2cinWRITEACK;
  assign SDA_Shift_State = i2cinADDRS | i2cinWRITE;

  //SDA_o handle
  always@(posedge clk)  begin
    SDA_o_buff <= (i2cinREAD & SCL_posedge) ? {SDA_o_buff[7:0], SDA} : SDA_o_buff;
  end

  //State transactions
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      state <= IDLE;
    end else case(state)
      IDLE: begin
        if(readFromMem)
          state <= READMEM;
        else if(writeToMem)
          state <= WRITEMEM;
        else if(dataUpdate)
          state <= UPDATE;
      end
      default: state <= (i2cFinished) ? IDLE : state;
    endcase
  end

  //Storing output values
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      data_reg <= 12'd0;
      mode_reg <= 2'd0;
    end else begin
      if((dataUpdate | writeToMem) & i2cinREADY) begin //Store values when I2C initiated
          data_reg <= data_i;
          mode_reg <= mode_i;
      end else if(inREADMEM & i2cinREADACK) begin //reading from mem
        case(i2cByteCounter)
          3'd5: begin
            mode_reg <= SDA_o_buff[6:5];
            data_reg[11:8] <= SDA_o_buff[3:0];
          end
          3'd6: data_reg[7:0] <= SDA_o_buff;
        endcase
      end
    end
  end

  //Divide i2c_double_clk
  always@(posedge clk or posedge rst) begin
    if(rst) begin
      i2c_clk <= 1'b1;
    end else begin
      i2c_clk <= i2c_clk ^ i2c_double_clk_posedge;
    end
  end
endmodule//mcp4725

//Following modules are support modules for generating clock frequencies 
module clkGen100MHz_6_25MHz(
  input clk100MHz,
  input rst,
  output reg clk6_25MHz);
  reg [2:0] counter;
  wire counterDone;

  assign counterDone = &counter;
  always@(posedge clk100MHz or posedge rst) begin
    if(rst) begin
      counter <= 3'd0;
    end else begin
      counter <= counter + 3'd1;
    end
  end
  always@(posedge clk100MHz or posedge rst) begin
    if(rst) begin
      clk6_25MHz <= 1'd0;
    end else begin
      clk6_25MHz <= (counterDone) ? ~clk6_25MHz : clk6_25MHz;
    end
  end
endmodule

module clkGenclk6_25MHz_3_12MHz(
  input clk6_25MHz,
  input rst,
  output reg clk3_12MHz);
  always@(posedge clk6_25MHz or posedge rst) begin
    if(rst) begin
      clk3_12MHz <= 1'b0;
    end else begin
      clk3_12MHz <= ~clk3_12MHz;
    end
  end
endmodule

module clkGen3_12MHz_781kHz(
  input clk3_12MHz,
  input rst,
  output reg clk781kHz);
  reg clk_mid;
  always@(posedge clk3_12MHz or posedge rst) begin
    if(rst) begin
      clk_mid <= 1'b0;
    end else begin
      clk_mid <= ~clk_mid;
    end
  end
  always@(posedge clk_mid or posedge rst) begin
    if(rst) begin
      clk781kHz <= 1'b0;
    end else begin
      clk781kHz <= ~clk781kHz;
    end
  end
endmodule

module clkGen_781kHz_195kHz(
  input clk781kHz,
  input rst,
  output reg clk195kHz);
  reg clk_mid;
  always@(posedge clk781kHz or posedge rst) begin
    if(rst) begin
      clk_mid <= 1'b0;
    end else begin
      clk_mid <= ~clk_mid;
    end
  end
  always@(posedge clk_mid or posedge rst) begin
    if(rst) begin
      clk195kHz <= 1'b0;
    end else begin
      clk195kHz <= ~clk195kHz;
    end
  end
endmodule
