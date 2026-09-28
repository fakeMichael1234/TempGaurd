/*
  TempGuard - ESP32 Firmware
  Hardware Requirements:
  - ESP32 Development Board
  - DS18B20 Temperature Sensor (Connected to GPIO 4 with a 4.7k pull-up resistor)
  - External LED (Connected to GPIO 2 or GPIO 18 with a 220-ohm resistor)
  - ESP32 Built-in Bluetooth / BLE

  BLE Architecture:
  - Service UUID: 4fafc201-1fb5-459e-8fcc-c5c9c331914b
  - Temp Characteristic UUID: beb5483e-36e1-4688-b7f5-ea07361b26a8 (READ, NOTIFY)
  - Min Temp Characteristic UUID: e3244fe0-50ac-4710-85f8-84226d9c7423 (READ, WRITE)
  - Max Temp Characteristic UUID: a19585e9-1111-4712-9c16-09559c5d120a (READ, WRITE)
  - Alert Status Characteristic UUID: c27c62ee-8e47-4933-bf9c-8515c1e55099 (READ, NOTIFY)
*/

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <Preferences.h>

// Pin Definitions
#define ONE_WIRE_BUS 4
#define LED_PIN 2 // Built-in LED on most ESP32 boards (or connect external LED to GPIO 2)


// UUID Definitions
#define SERVICE_UUID           "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define TEMP_CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define MIN_TEMP_CHARACTERISTIC_UUID "e3244fe0-50ac-4710-85f8-84226d9c7423"
#define MAX_TEMP_CHARACTERISTIC_UUID "a19585e9-1111-4712-9c16-09559c5d120a"
#define ALERT_CHARACTERISTIC_UUID "c27c62ee-8e47-4933-bf9c-8515c1e55099"

// DS18B20 Setup
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature sensors(&oneWire);

// NVS Persistence
Preferences preferences;

// BLE Objects & State
BLEServer* pServer = NULL;
BLECharacteristic* pTempCharacteristic = NULL;
BLECharacteristic* pMinTempCharacteristic = NULL;
BLECharacteristic* pMaxTempCharacteristic = NULL;
BLECharacteristic* pAlertCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Temperature Thresholds & Alert State
float minTemp = 2.0;
float maxTemp = 8.0;
float currentTemp = 0.0;

// Alert States: 0 = NORMAL, 1 = LOW, 2 = HIGH
int currentAlertState = 0;

// Timing Variables (Non-blocking using millis)
unsigned long lastSensorReadTime = 0;
const unsigned long sensorReadInterval = 1000; // Read sensor every 1 second

unsigned long lastBlinkTime = 0;
const unsigned long blinkInterval = 300; // Blink LED every 300ms when alerting
bool ledState = LOW;

// BLE Server Connection Callbacks
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Client Connected to TempGuard BLE Server");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Client Disconnected from TempGuard BLE Server");
    }
};

// BLE Callback for Min Temp Writes
class MinTempCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String value = pCharacteristic->getValue().c_str();
      if (value.length() > 0) {
        float val = value.toFloat();
        if (val != 0.0 || value == "0" || value == "0.0") {
          minTemp = val;
          preferences.putFloat("minTemp", minTemp);
          Serial.print("Updated Min Temp Threshold: ");
          Serial.println(minTemp);
        }
      }
    }
};

// BLE Callback for Max Temp Writes
class MaxTempCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String value = pCharacteristic->getValue().c_str();
      if (value.length() > 0) {
        float val = value.toFloat();
        if (val != 0.0 || value == "0" || value == "0.0") {
          maxTemp = val;
          preferences.putFloat("maxTemp", maxTemp);
          Serial.print("Updated Max Temp Threshold: ");
          Serial.println(maxTemp);
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Initialize NVS Preferences to restore saved temperature limits
  preferences.begin("tempguard", false);
  minTemp = preferences.getFloat("minTemp", 2.0);
  maxTemp = preferences.getFloat("maxTemp", 8.0);
  Serial.print("Loaded Saved Min Temp: "); Serial.println(minTemp);
  Serial.print("Loaded Saved Max Temp: "); Serial.println(maxTemp);

  // Initialize DS18B20 Sensor
  sensors.begin();

  // Create the BLE Device
  BLEDevice::init("TempGuard");

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create Temperature Characteristic (READ, NOTIFY)
  pTempCharacteristic = pService->createCharacteristic(
                          TEMP_CHARACTERISTIC_UUID,
                          BLECharacteristic::PROPERTY_READ |
                          BLECharacteristic::PROPERTY_NOTIFY
                        );
  pTempCharacteristic->addDescriptor(new BLE2902());

  // Create Min Temp Characteristic (READ, WRITE)
  pMinTempCharacteristic = pService->createCharacteristic(
                             MIN_TEMP_CHARACTERISTIC_UUID,
                             BLECharacteristic::PROPERTY_READ |
                             BLECharacteristic::PROPERTY_WRITE
                           );
  pMinTempCharacteristic->setCallbacks(new MinTempCallbacks());
  String minStr = String(minTemp, 2);
  pMinTempCharacteristic->setValue(minStr.c_str());

  // Create Max Temp Characteristic (READ, WRITE)
  pMaxTempCharacteristic = pService->createCharacteristic(
                             MAX_TEMP_CHARACTERISTIC_UUID,
                             BLECharacteristic::PROPERTY_READ |
                             BLECharacteristic::PROPERTY_WRITE
                           );
  pMaxTempCharacteristic->setCallbacks(new MaxTempCallbacks());
  String maxStr = String(maxTemp, 2);
  pMaxTempCharacteristic->setValue(maxStr.c_str());

  // Create Alert Status Characteristic (READ, NOTIFY)
  pAlertCharacteristic = pService->createCharacteristic(
                           ALERT_CHARACTERISTIC_UUID,
                           BLECharacteristic::PROPERTY_READ |
                           BLECharacteristic::PROPERTY_NOTIFY
                         );
  pAlertCharacteristic->addDescriptor(new BLE2902());
  pAlertCharacteristic->setValue("0"); // Default NORMAL

  // Start the BLE Service
  pService->start();

  // Start Advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06); // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("TempGuard BLE Server Started & Advertising...");
}

void loop() {
  unsigned long currentMillis = millis();

  // 1. Read Sensor & Perform Local Temperature Comparison (Every 1s)
  if (currentMillis - lastSensorReadTime >= sensorReadInterval) {
    lastSensorReadTime = currentMillis;

    sensors.requestTemperatures();
    float readTemp = sensors.getTempCByIndex(0);

    // Filter out invalid sensor readings (DS18B20 returns -127 on error)
    if (readTemp != -127.00 && readTemp != 85.00) {
      currentTemp = readTemp;

      // Hardware/Local Alert Logic (Runs even if phone is disconnected)
      int newAlertState = 0;
      if (currentTemp < minTemp) {
        newAlertState = 1; // LOW TEMPERATURE
      } else if (currentTemp > maxTemp) {
        newAlertState = 2; // HIGH TEMPERATURE
      } else {
        newAlertState = 0; // NORMAL
      }

      currentAlertState = newAlertState;

      // Update BLE characteristics & send notifications if connected
      if (deviceConnected) {
        // Temperature notification
        String tempStr = String(currentTemp, 2);
        pTempCharacteristic->setValue(tempStr.c_str());
        pTempCharacteristic->notify();

        // Alert status notification
        String alertStr = String(currentAlertState);
        pAlertCharacteristic->setValue(alertStr.c_str());
        pAlertCharacteristic->notify();
      }

      Serial.print("Temp: ");
      Serial.print(currentTemp);
      Serial.print(" °C | Min: ");
      Serial.print(minTemp);
      Serial.print(" | Max: ");
      Serial.print(maxTemp);
      Serial.print(" | Alert State: ");
      Serial.println(currentAlertState);
    } else {
      Serial.println("Error reading DS18B20 temperature sensor!");
    }
  }

  // 2. Hardware LED Control (Non-blocking millis blinking)
  if (currentAlertState != 0) {
    // Alert state active (LOW or HIGH): Blink Warning LED
    if (currentMillis - lastBlinkTime >= blinkInterval) {
      lastBlinkTime = currentMillis;
      ledState = !ledState;
      digitalWrite(LED_PIN, ledState);
    }
  } else {
    // Normal state: Turn off LED
    digitalWrite(LED_PIN, LOW);
  }

  // 3. Handle BLE Re-advertising on Disconnect
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // Give BLE stack a chance to settle
    pServer->startAdvertising(); // Restart advertising so phone can reconnect
    Serial.println("Restarted BLE Advertising");
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
}
