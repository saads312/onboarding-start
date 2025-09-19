module spi_peripheral #(
  parameter MAX_ADDRESS = 0x04
) (
  input wire rst,
  input wire sCLK, // spi domain clock
  input wire clk,  // fast clock
  input wire nCS,
  input wire COPI,
  output reg [7:0] en_reg_out_7_0,
  output reg [7:0] en_reg_out_15_8,
  output reg [7:0] en_reg_pwm_7_0,
  output reg [7:0] en_reg_pwm_15_8,
  output reg [7:0] pwm_duty_cycle
);

reg [2:0] sCLK_sync;
reg [2:0] nCS_sync;
reg [1:0] COPI_sync;

reg [5:0] bit_count; // 16 bits !!

reg rw_select; // 1 bit r/w, read (0) is ignored
reg [6:0] address; // 7 bit address
reg [7:0] data; // 8 bit data

reg tx_ready, tx_valid; // no partial updates

always @(posedge clk or posedge rst) begin
  if (rst) begin
    en_reg_out_7_0 <= 0x00; en_reg_out_15_8 <= 0x00; en_reg_pwm_7_0 <= 0x00; en_reg_pwm_15_8 <= 0x00; pwm_duty_cycle <= 0x00; 
    tx_valid <= 0;
  end else if (tx_ready && !tx_valid) begin
    if (rw_select) begin
      if (address <= MAX_ADDRESS) begin
        if (address == 0x00) en_reg_out_7_0 <= data;
        if (address == 0x01) en_reg_out_15_8 <= data;
        if (address == 0x02) en_reg_pwm_7_0 <= data;
        if (address == 0x03) en_reg_pwm_15_8 <= data;
        if (address == 0x04) pwm_duty_cycle <= data;
      end
    end
    tx_valid <= 1;
  end else if (!tx_ready && tx_valid) begin
    tx_valid <= 0;
  end
end

always @(posedge clk or posedge rst) begin
  if (rst) begin
    
    sCLK_sync <= 0;
    nCS_sync <= 3'b111;
    COPI_sync <= 0;
    
    bit_count <= 0;

    rw_select <= 0; address <= 0; data <= 0;

    tx_ready <= 0;
  
  end else begin
    
    sCLK_sync <= {sCLK_sync[1:0], sCLK};
    nCS_sync <= {nCS_sync[1:0], nCS};
    COPI_sync <= {COPI_sync[0], COPI};

    if (nCS_sync[2] && !nCS_sync[1]) begin // falling edge, reset everything
      bit_count <= 0;
      rw_select <= 0;
      address <= 0;
      data <= 0;
    end

    if (!nCS_sync[1]) begin
      if (!sCLK_sync[2] && sCLK_sync[1]) begin // rising edge of clock
        if (bit_count < 1) begin
          rw_select <= COPI_sync[1];
        end else if (bit_count < 9) begin
          address <= {address[5:0], COPI_sync[1]};
        end else if (bit_count < 16) begin
          data <= {data[6:0], COPI_sync[1]};
        end
        if (bit_count < 16) bit_count <= bit_count + 1;
      end
    end

    if (!nCS_sync[2] && nCS_sync[1]) begin // rising edge, tx over
      if (bit_count == 16) begin // check for all bits
        tx_ready <= 1;
        bit_count <= 0;
      end
    end

    if (tx_valid) tx_ready <= 0;

  end
end

endmodule
