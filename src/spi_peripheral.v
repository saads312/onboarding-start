module spi_peripheral #(
  localparam MAX_ADDRESS = 0x04;
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

reg sCLK1, sCLK2, sCLK3;
reg nCS1, nCS2, nCS3;
reg COPI1, COPI2;

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
    
    sCLK1 <= 0; sCLK2 <= 0; sCLK3 <= 0;
    nCS1 <= 1; nCS2 <= 1;
    COPI1 <= 0; COPI2 <= 0;
    
    bit_count <= 0;

    rw_select <= 0; address <= 0; data <= 0;

    tx_ready <= 0;
  
  end else begin
    
    sCLK1 <= sCLK;
    sCLK2 <= sCLK1;
    sCLK3 <= sCLK2;

    nCS1 <= nCS;
    nCS2 <= nCS1;
    nCS3 <= nCS2;

    COPI1 <= COPI;
    COPI2 <= COPI1;

    if (nCS3 && !nCS2) begin // falling edge, reset everything
      bit_count <= 0;
      rw_select <= 0;
      address <= 0;
      data <= 0;
    end

    if (!nCS2) begin
      if (!sCLK3 && sCLK2) begin // rising edge of clock
        if (bit_count < 1) begin
          rw_select <= COPI2;
        end else if (bit_count < 9) begin
          address <= {address[5:0], COPI2};
        end else if (bit_count < 16) begin
          data <= {data[6:0], COPI2};
        end
        if (bit_count < 16) bit_count <= bit_count + 1;
      end
    end

    if (!nCS3 && nCS2) begin // rising edge, tx over
      if (bit_count == 16) begin // check for all bits
        tx_ready <= 1;
        bit_count <= 0;
      end
    end

    if (tx_valid) tx_ready <= 0;

  end
end

endmodule
