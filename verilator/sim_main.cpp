#include <verilated.h>
#include <iostream>
#include "Vfp32_mult.h"
#include <math.h>
#include <random>

#define PI 3.14159

Vfp32_mult *fp32_mult;

vluint64_t main_time = 0;

int samplecount = 0;

int currentsample;

double sc_time_stamp() {
  return main_time;
}

int main(int argc, char** argv) {
  fp32_mult = new Vfp32_mult;

  fp32_mult->rstn = 1;

  for(int i = 0; i < 1000; i++) {
    if(main_time > 100) {
      fp32_mult->rstn = 0;
    }

    if((main_time%10) == 1) {
      fp32_mult->clk = 1;
      if(fp32_mult->rstn == 0) {
        float floati_0 = 1.0f;
        float floati_1 = 1.0f;
        fp32_mult->floati_0 = floati_0;
        fp32_mult->floati_1 = floati_1;
      }
    }

    if((main_time%10) == 6) {
      fp32_mult-> clk = 0;
    }
    fp32_mult->eval();
    if((main_time%10) == 1 && fp32_mult->reset == 0) {
      std::cout << "Output: " << (fp32_mult->floato) << '\n';
    }

    main_time++;
  }

  fp32_mult->final();

  return 0;
}
