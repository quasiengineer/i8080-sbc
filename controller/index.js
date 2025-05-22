/* eslint-disable no-console */

import * as path from 'node:path';
import EventEmitter from 'node:events';
import * as fs from 'node:fs';
import { fileURLToPath } from 'node:url';

import { SerialPort } from 'serialport';

const args = process.argv.slice(2);
const argsMap = Object.fromEntries(args.map((arg) => arg.replace(/^-/, '').split('=')));

const BAUD_RATE = 115200;
const DEFAULT_PORT_NAME = 'COM19';

const InCommandType = Object.freeze({ CmdAck: 0x01, CmdResult: 0x02, CmdPrintTime: 0x05 });
const OutCommandType = Object.freeze({ CmdWriteDump: 0x01, CmdWriteByte: 0x02, CmdReadByte: 0x03, CmdReset: 0x04 });

const eventBus = new EventEmitter();

const sendCommand = (port, opcode, data) => new Promise((resolve, reject) => {
  const result = [];
  const writeResult = ({ resultByte }) => result.push(resultByte);
  eventBus.on('result', writeResult);

  eventBus.once('ack', () => {
    eventBus.off('result', writeResult);
    resolve(result);
  });

  port.write(Buffer.from([opcode, ...(data ?? [])]), (err) => err && reject(err));
});

const processInputCommand = (buf, offset, len) => {
  switch (buf[offset]) {
    case InCommandType.CmdAck:
      eventBus.emit('ack');
      return 1;

    case InCommandType.CmdResult:
      if (len - offset < 2) {
        return 0;
      }
      eventBus.emit('result', { resultByte: buf[offset + 1] });
      return 2;

    case InCommandType.CmdPrintTime:
      console.log(`\nCurrent time: ${Date.now()}ms\n`);
      return 1;

    default:
      process.stdout.write(String.fromCharCode(buf[offset]));
      return 1;
  }
};

/*
 * Process received data
 */
const processIncomingData = (port) => {
  let currentBuf = Buffer.alloc(0);

  port.on('data', async (data) => {
    let processed = 0;

    currentBuf = Buffer.concat([currentBuf, data]);
    const bufLen = currentBuf.length;
    while (processed < bufLen) {
      const consumed = processInputCommand(currentBuf, processed, bufLen);
      if (!consumed) {
        break;
      }

      processed += consumed;
    }

    currentBuf = currentBuf.subarray(processed);
  });
};

/*
 * Open port
 */
const openPort = (portName) => new Promise((resolve, reject) => {
  const port = new SerialPort({ baudRate: BAUD_RATE, path: portName || DEFAULT_PORT_NAME }, (openErr) => {
    if (openErr) {
      reject(openErr);
      return;
    }

    port.on('error', (err) => console.log('Error: ', err.message || err));

    processIncomingData(port);

    resolve(port);
  });
});

const main = async () => {
  const port = await openPort(argsMap.port);
  const dirName = path.dirname(fileURLToPath(import.meta.url));

  const romImage = fs.readFileSync(path.resolve(dirName, argsMap.rom));
  const romSize = romImage.length;
  await sendCommand(port, OutCommandType.CmdWriteDump, [romSize >> 8, romSize & 0xFF, ...[...romImage].toReversed()]);
  console.log('[+] Dump has been written to memory');

  if ('verify' in argsMap) {
    console.log('[~] Verifying dump...');
    for (let addr = romSize - 1; addr >= 0; --addr) {
      const expected = romImage[addr];
      const cmdResp = await sendCommand(port, OutCommandType.CmdReadByte, [addr >> 8, addr & 0xFF]);
      if (expected !== cmdResp[0]) {
        console.log(`ALARM, wrong data has been read!, addr = ${addr}, expected = ${expected.toString(16)} got = ${cmdResp[0].toString(16)}`);
        process.exit(0);
      }
    }
    console.log('[+] All good!');
  }

  await sendCommand(port, OutCommandType.CmdReset);
  console.log('[+] Reset i8080...');
  console.log('[~] Output from i8080:\n');

  // setTimeout(() => process.exit(0), 5000);
};

main()
  .catch((err) => {
    console.error('Error', err.message, err);
    process.exit();
  });
