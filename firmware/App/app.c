#include "main.h"

#include "app.h"
#include "fpgaInterface.h"
#include "hostInterface.h"

#define LED_FLICKERING_PERIOD_IN_MS 2000

static uint32_t ledToggledTs = 0;

/*
 * Infinite loop
 */
void infiniteLoopIteration() {
  uint32_t currentTs = HAL_GetTick();

  flushData();

  if (currentTs - ledToggledTs > LED_FLICKERING_PERIOD_IN_MS) {
    // flickering LED
    HAL_GPIO_TogglePin(LED_OUT_GPIO_Port, LED_OUT_Pin);
    ledToggledTs = currentTs;
  }
}

void initApp(UART_HandleTypeDef * huart) {
  initFPGAInterface(huart);
}