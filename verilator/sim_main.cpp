#include <verilated.h>
#include <iostream>
#include "Vfp32_mult.h"
#include <math.h>
#include <random>

Vfp32_mult *fp32_mult;

vluint64_t main_time = 0;

int samplecount = 0;

float inputs[4][2];

double sc_time_stamp() {
  return main_time;
}


/*
 * Adds two float inputs to multiplier and input array.
 */
void add_inputs(float input0, float input1) {
    uint32_t input_uint_0 = * ( uint32_t * ) &input0;
    uint32_t input_uint_1 = * ( uint32_t * ) &input1;
    fp32_mult->floati_0 = input_uint_0;
    fp32_mult->floati_1 = input_uint_1;
    inputs[3][0] = inputs[2][0];
    inputs[3][1] = inputs[2][1];
    inputs[2][0] = inputs[1][0];
    inputs[2][1] = inputs[1][1];
    inputs[1][0] = inputs[0][0];
    inputs[1][1] = inputs[0][1];
    inputs[0][0] = input0;
    inputs[0][1] = input1;
}

int main(int argc, char** argv) {

    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<> dis(0.0, 100.0);

    fp32_mult = new Vfp32_mult;

    fp32_mult->rstn = 0;

    for(int i = 0; i < 1000; i++) {
        if(main_time > 100) {
          fp32_mult->rstn = 1;
        }

        if((main_time%10) == 1) {
            fp32_mult->clk = 1;
            if(fp32_mult->rstn == 1) {
                add_inputs(dis(gen), dis(gen));
            }
        }

        if((main_time%10) == 6) {
            fp32_mult-> clk = 0;
        }
        fp32_mult->eval();
        if((main_time%10) == 1 && fp32_mult->rstn == 1) {
            uint32_t uint_o = fp32_mult->floato;
            float output_float = * ( float * ) &uint_o;
            float expected_output = inputs[3][0] * inputs[3][1];
            std::cout << "Inputs: " << inputs[3][0] << " " << inputs[3][1] << ". Expected output: " << expected_output << ". Actual output: " << output_float << ". Deviation: " << (abs((expected_output - output_float) / expected_output) * 100) << "%\n";
        }
        main_time++;
    }
    fp32_mult->final();

    return 0;
}
