#pragma once

#include <stdint.h>

void addDataToQueue(uint8_t data);
void flushData();
void handleDataFromHost(uint8_t * data, uint16_t dataLen);