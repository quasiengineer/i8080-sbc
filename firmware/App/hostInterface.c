#include "usbd_cdc_if.h"
#include "hostInterface.h"
#include "fpgaInterface.h"

#define TRANSFER_SIZE 1024
#define TRANSFER_CHUNK_SIZE 128

typedef struct {
  uint8_t buffer[TRANSFER_SIZE];
  volatile uint16_t writePtr;
  volatile uint16_t readPtr;
} RingBuffer;

static RingBuffer transferQueue = { .writePtr = 0, .readPtr = 0 };

/*
 * ================================
 *              OUTPUT
 * ================================
 */

extern USBD_HandleTypeDef hUsbDeviceFS;

void addDataToQueue(uint8_t data) {
  __disable_irq();
  transferQueue.buffer[transferQueue.writePtr] = data;
  transferQueue.writePtr = (transferQueue.writePtr + 1) % TRANSFER_SIZE;
  __enable_irq();
}

void flushData() {
  uint8_t transferChunk[TRANSFER_CHUNK_SIZE];

  // we don't want to disable IRQs for a long time, so at first we just copying chunk of queue into small buffer
  __disable_irq();
  uint16_t writePtr = transferQueue.writePtr, readPtr = transferQueue.readPtr;
  uint16_t transferSize = (writePtr >= readPtr) ? (writePtr - readPtr) : (TRANSFER_SIZE - readPtr);
  uint8_t chunkSize = (transferSize > TRANSFER_CHUNK_SIZE) ? TRANSFER_CHUNK_SIZE : transferSize;
  for (uint8_t i = 0; i < chunkSize; ++i) {
    transferChunk[i] = transferQueue.buffer[readPtr];
    readPtr = (readPtr + 1) % TRANSFER_SIZE;
  }
  transferQueue.readPtr = readPtr;
  __enable_irq();

  if (!chunkSize) {
    return;
  }

  while (CDC_Transmit_FS(transferChunk, chunkSize) != USBD_OK);
}

void handleDataFromHost(uint8_t * data, uint16_t dataLen) {
  sendDataToFPGA(data, dataLen);
}
