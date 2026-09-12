// Demo code for Bluetooth Low Energy on the Seed Studio XIAO MG24 Sense Board
// make sure to select the Protocol stack "BLE (SiLabs)" in the Arduino IDE!
// based on an example from Seed Studio
#define RF_SW_PW_PIN PB5
#define RF_SW_PIN PB4

bool notification_enabled = false;

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);
  Serial.begin(115200);
  Serial.println("OpenToF BLE Test\n");

  // configure the antenna
  pinMode(PB5, OUTPUT);
  pinMode(PB4, OUTPUT);
  digitalWrite(PB4, LOW); // build-in antenna
  digitalWrite(PB5, HIGH); // power on rf-switch

  delay(100);
}

void loop() {
  if (notification_enabled) {
    // Send a notification every two seconds with the message 'hello world'
    send_tof_notification();
  }
  delay(1000);
}

// void ble_initialize_gatt_db();
static void ble_start_advertising();
extern uint16_t tof_characteristic_handle;
extern uint16_t last_tof;

// callback for the BLE stack
void sl_bt_on_event(sl_bt_msg_t *evt) {
  switch (SL_BT_MSG_ID(evt->header)) {
    case sl_bt_evt_system_boot_id: // BLE stack ready
      {
        Serial.println("BLE stack booted");

        // Initialize the application specific GATT table
        ble_initialize_gatt_db();

        // Start advertising
        ble_start_advertising();
        Serial.println("BLE advertisement started");
      }
      break;

    case sl_bt_evt_connection_opened_id: // client connected
      Serial.println("BLE connection opened");
      break;

    case sl_bt_evt_connection_closed_id: // client disconnected
      Serial.println("BLE connection closed");
      // Restart the advertisement
      ble_start_advertising();
      Serial.println("BLE advertisement restarted");
      break;

    case sl_bt_evt_gatt_server_characteristic_status_id: // GATT characteristic changed
      // If the 'ToF' characteristic has been changed
      // TOOD: Also check for battery characteristic
      if (evt->data.evt_gatt_server_characteristic_status.characteristic == tof_characteristic_handle) {
        // The client just enabled the notification - send notification of the current state
        if (evt->data.evt_gatt_server_characteristic_status.client_config_flags & sl_bt_gatt_notification) {
          Serial.println("change notification enabled");
          notification_enabled = true;
        } else {
          Serial.println("change notification disabled");
          notification_enabled = false;
        }
      }
      break;

    default: // unhandled event, ignored
      break;
  }
}

/**************************************************************************/ /**
 * Sends a BLE notification the the client if notifications are enabled 
 *****************************************************************************/
static void send_tof_notification() {
  sl_status_t sc = sl_bt_gatt_server_write_attribute_value(tof_characteristic_handle, 0, sizeof(last_tof), (const uint8_t *)&last_tof);
  app_assert_status(sc);
  sc = sl_bt_gatt_server_notify_all(tof_characteristic_handle, sizeof(last_tof), (const uint8_t *)&last_tof);
  last_tof++;
  if (sc == SL_STATUS_OK) {
    Serial.println("Send notification!");
  }
}

/**************************************************************************/ /**
 * Starts BLE advertisement
 * Initializes advertising if it's called for the first time
 *****************************************************************************/
static void ble_start_advertising() {
  static uint8_t advertising_set_handle = 0xff;
  static bool init = true;
  sl_status_t sc;

  if (init) {
    // Create an advertising set
    sc = sl_bt_advertiser_create_set(&advertising_set_handle);
    app_assert_status(sc);

    // Set advertising interval to 100ms
    sc = sl_bt_advertiser_set_timing(
      advertising_set_handle,
      160,  // minimum advertisement interval (milliseconds * 1.6)
      160,  // maximum advertisement interval (milliseconds * 1.6)
      0,    // advertisement duration
      0);   // maximum number of advertisement events
    app_assert_status(sc);

    init = false;
  }

  // Generate data for advertising
  sc = sl_bt_legacy_advertiser_generate_data(advertising_set_handle, sl_bt_advertiser_general_discoverable);
  app_assert_status(sc);

  // Start advertising and enable connections
  sc = sl_bt_legacy_advertiser_start(advertising_set_handle, sl_bt_advertiser_connectable_scannable);
  app_assert_status(sc);
}

