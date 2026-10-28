#include <Wire.h>
#include <LSM6DS3.h>
#include <string.h>

// XIAO MG24 Sense:
// LSM6DS3TR-C I2C address is 0x6A.
LSM6DS3 myIMU(I2C_MODE, 0x6A);

// Maximum gyro rate is 1.66kHz, Accel would go up to 6.66kHz
constexpr uint16_t SENSOR_ODR_HZ = 208;//416;//208;//833;
// FIFO rate should be the same, don't know why this is listed as 1600
constexpr uint16_t FIFO_ODR_HZ = 200;//400;

// if true, print in ASCII
constexpr bool ascii_mode = false;

// Gyro (3 words), accel (3 words), timestamp (3 words).
constexpr uint16_t FIFO_WORDS_PER_SAMPLE = 9;

// Binary packet:
//   int16_t gyro X
//   int16_t gyro Y
//   int16_t gyro Z
//   int16_t accel X
//   int16_t accel Y
//   int16_t accel Z
//   uint32_t raw timestamp (24 significant bits, 25 us/tick)
//
// = 16 bytes/sample, 22 bytes including marker/counter/debugData.
struct __attribute__((packed)) ImuSample
{
  int16_t gx;
  int16_t gy;
  int16_t gz;
  int16_t ax;
  int16_t ay;
  int16_t az;
  uint32_t timestamp;
};

static_assert(sizeof(ImuSample) == 16, "Unexpected packet size");

void sendSample(const uint16_t debugData, const ImuSample &sample)
{
  static uint16_t packetCounter = 0;

  Serial.write(0xAA); // marker byte 1
  Serial.write(0x55); // marker byte 2
  Serial.write(reinterpret_cast<const uint8_t *>(&packetCounter), sizeof(packetCounter));
  packetCounter++;
  Serial.write(reinterpret_cast<const uint8_t *>(&debugData), sizeof(debugData));
  Serial.write(reinterpret_cast<const uint8_t *>(&sample),
               sizeof(sample));
}

void sendSampleAscii(const ImuSample &sample)
{
  Serial.print(myIMU.calcAccel(sample.ax), 3);
  Serial.write(",");
  Serial.print(myIMU.calcAccel(sample.ay), 3);
  Serial.write(",");
  Serial.print(myIMU.calcAccel(sample.az), 3);
  Serial.write(",");
  Serial.print(myIMU.calcGyro(sample.gx), 3);
  Serial.write(",");
  Serial.print(myIMU.calcGyro(sample.gy), 3);
  Serial.write(",");
  Serial.print(myIMU.calcGyro(sample.gz), 3);
  Serial.write(",");
  Serial.print(sample.timestamp);
  Serial.write("\n");
}

void setup()
{
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);

  // we need a pretty high baud rate
  Serial.begin(921600);

  while (!Serial);

  // turn on IMU power
  pinMode(PD5, OUTPUT);
  digitalWrite(PD5, HIGH);

  // set I2C to 400 kHz
  Wire.setClock(400000);

  // Configure the IMU
  myIMU.settings.gyroEnabled = 1;
  myIMU.settings.gyroRange = 2000; //max deg/s
  myIMU.settings.gyroBandWidth = 400; //Hz
  myIMU.settings.gyroSampleRate = SENSOR_ODR_HZ;

  myIMU.settings.accelEnabled = 1;
  myIMU.settings.accelRange = 16; //max g
  myIMU.settings.accelBandWidth = 400; //Hz
  myIMU.settings.accelSampleRate = SENSOR_ODR_HZ;

  // Include both sensors in the FIFO.
  myIMU.settings.gyroFifoEnabled = 1;
  myIMU.settings.gyroFifoDecimation = 1;

  myIMU.settings.accelFifoEnabled = 1;
  myIMU.settings.accelFifoDecimation = 1;

  myIMU.settings.timestampEnabled = 1;
  myIMU.settings.timestampFifoEnabled = 1;
  myIMU.settings.timestampResolution = 1; // Maximum resolution: 25 us/tick

  // FIFO configuration.
  myIMU.settings.fifoSampleRate = FIFO_ODR_HZ;
  myIMU.settings.fifoModeWord = 6; // continuous
  myIMU.settings.fifoThreshold = 512;

  // Temperature is unnecessary
  myIMU.settings.tempEnabled = 0;

  if (myIMU.begin() != 0) {
    // ASCII error is OK because this happens only during startup.
    Serial.println("LSM6DS3 initialization failed");
    while (1);
  }

  if (ascii_mode) {
    // write a header so this can be used as CSV file
    Serial.write("ax,ay,az,gx,gy,gz,timestamp\n");
  }

  myIMU.fifoBegin();

  // workarround
  myIMU.writeRegister(LSM6DS3_ACC_GYRO_FIFO_CTRL4, 0x08); // disabled dataset 3, enable only 4

  // wait a bit for everything to settle
  delay(10);

  // clear the FIFO, we are ready to go
  myIMU.fifoClear();

  // turn on LED for synchronisation with a camera
  digitalWrite(LED_BUILTIN, LED_BUILTIN_ACTIVE);
}

void loop()
{
  // check for reset command
  if (Serial.available()) {
    char c = Serial.read();
    if (c == 'r') {
      digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);
      delay(100);
      myIMU.fifoClear();
      digitalWrite(LED_BUILTIN, LED_BUILTIN_ACTIVE);
    }
  }

  int16_t status = myIMU.fifoGetStatus();
  uint16_t words = status & 0x07FF;

  while (words >= FIFO_WORDS_PER_SAMPLE)
  {

    // Read one complete gyro + accel + timestamp FIFO sample in a single burst.
    ImuSample sample;
    uint8_t raw[FIFO_WORDS_PER_SAMPLE * 2];
    myIMU.readRegisterRegion(raw, LSM6DS3_ACC_GYRO_FIFO_DATA_OUT_L, sizeof(raw));

    memcpy(&sample, raw, 12); // copy accel + gyro
    // Dataset 4: timestamp[15:8], timestamp[23:16], unused, timestamp[7:0], steps[7:0], steps[15:8]
    sample.timestamp = static_cast<uint32_t>(raw[15])
                     | (static_cast<uint32_t>(raw[12]) << 8)
                     | (static_cast<uint32_t>(raw[13]) << 16);

    if (!ascii_mode) {
        sendSample(words, sample);
    } else {
        sendSampleAscii(sample);
    }

    words -= FIFO_WORDS_PER_SAMPLE;
  }
}
