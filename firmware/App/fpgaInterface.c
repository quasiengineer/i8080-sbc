#include "main.h"
#include "fpgaInterface.h"
#include "hostInterface.h"

static uint8_t inputChar;
static UART_HandleTypeDef * uartInterface;

void initFPGAInterface(UART_HandleTypeDef * huart) {
  uartInterface = huart;

  HAL_UART_Receive_IT(huart, &inputChar, sizeof(inputChar));
}

void HAL_UART_RxCpltCallback(UART_HandleTypeDef *huart) {
  addDataToQueue(inputChar);
  HAL_UART_Receive_IT(huart, &inputChar, sizeof(inputChar));
}

void sendDataToFPGA(uint8_t * data, uint16_t sz) {
  HAL_UART_Transmit(uartInterface, data, sz, -1);
}