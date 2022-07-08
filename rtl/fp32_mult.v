module fp32_mult (input [31:0] floati_0, input [31:0] floati_1, input rstn, input clk,
        output floato);
    // Multiplies 2 IEEE-754 32-bit fl0ating p0int numbers. Optimized for Xilinx DSP48 slice architecture (24x17-bit unsigned multiplication capability)
    // Because of performance optimizations for Xilinx hardware, will not have bit-perfect results (comparable to -fast_math on CUDA systems, probably less accurate)
    // Discards least-significant 7 bits of floati_1
    wire [31:0] floati_0, floati_1, floato;
    wire rstn, clk;
    reg [23:0] mant_0;
    reg [16:0] mant_1;
    reg [8:0] expsum [2:0];
    reg [40:0] mantprod;
    reg [1:0] lownums [2:0];
    reg [5:0] nan_inf_zero [2:0];



    always @(posedge clk) begin
        if (rstn == 1'b0) begin
            expsum[0] <= 9'b0;
            expsum[1] <= 9'b0;
            expsum[2] <= 9'b0;
            mantprod <= 41'b0;
            mant_0 <= 24'b0;
            mant_1 <= 17'b0;
            lownums[0] <= 2'b0;
            lownums[1] <= 2'b0;
            lownums[2] <= 2'b0;
        end
        else begin
            // stage 1
            if (floati_0[30:23] == 8'b0) begin
                if (floati_0[22:0] == 23'b0)
                    nan_inf_zero[0][2] <= 1'b1;
                else
                    nan_inf_zero[0][2] <= 1'b0;
                mant_0 <= {floati_0[22:0], 1'b0};
                lownums[0][0] <= 1'b1;
            end
            else begin
                mant_0 <= {1'b1, floati_0[22:0]};
                lownums[0][0] <= 1'b0;
            end
            if (floati_1 [31:24] == 8'b0) begin
                if (floati_1[22:0] == 23'b0)
                    nan_inf_zero[0][5] <= 1'b1;
                else
                    nan_inf_zero[0][5] <= 1'b0;
                mant_1 <= floati_1[23:7];
                lownums[0][1] <= 1'b1;
            end
            else begin
                mant_1 <= {1'b1, floati_1[23:8]};
                lownums[0][1] <= 1'b0;
            end
            if (floati_0[30:23] == 8'b1111_1111) begin
                if (floati_0[22:0] == 23'b0) begin
                    nan_inf_zero[0][1] <= 1;
                    nan_inf_zero[0][0] <= 0;
                end
                else begin
                    nan_inf_zero[0][1] <= 0;
                    nan_inf_zero[0][0] <= 1;
                end
            end
            if (floati_1[30:23] == 8'b1111_1111) begin
                if (floati_1[22:0] == 23'b0) begin
                    nan_inf_zero[0][4] <= 1;
                    nan_inf_zero[0][3] <= 0;
                end
                else begin
                    nan_inf_zero[0][4] <= 0;
                    nan_inf_zero[0][3] <= 1;
                end
            end
            expsum[0] <= floati_0[31:24] + floati_1[31:24]; // adds the exponents, nothing fancy here
            // at this point, mantissas are ready for multiplication, and exponents are added
            // lownums represents whether either of the exponents are in non-normalized mode
            // we don't have to worry about them both being non-normalized since that results in underflow anyway
            // end stage 1
            // stage 2
            lownums[1] <= lownums[0];
            mantprod <= mant_0 * mant_1;
            if (expsum[0] < 9'd127) begin
                expsum[1] <= 9'd0;
                {nan_inf_zero[1][2], nan_inf_zero[1][5]} <= 2'b11;
                {nan_inf_zero[1][4:3], nan_inf_zero[1][1:0]} <= {nan_inf_zero[0][4:3], nan_inf_zero[0][1:0]};
                // underflow (result should be 0)
            end
            else if (expsum[0] > 9'b382) begin // 382 == 255 + 127
                expsum[1] <= 9'd255;
                {nan_inf_zero[1][1], nan_inf_zero[1][4]} <= 2'b11;
                {nan_inf_zero[1][5], nan_inf_zero[1][3:2], nan_inf_zero[1][0]} <= {nan_inf_zero[0][5], nan_inf_zero[0][3:2], nan_inf_zero[0][0]};
                // overflow (result should be INF)
            end
            else begin
                expsum[1] <= expsum[0] - 9'd255;
                nan_inf_zero[1] <= nan_inf_zero[0];
            end
            // product of mantissas is now computed, and expsum[1] is corrected for overflow / underflow
            // nan_inf_zero now correctly represents corner cases of float multiplication
            // end stage 2
            // begin stage 3

        end
    end
endmodule // fp32_mult
