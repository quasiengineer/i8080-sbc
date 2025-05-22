#pragma once

#include <stdint.h>

void initFPGAInterface(UART_HandleTypeDef * huart);
void sendDataToFPGA(uint8_t * data, uint16_t sz);