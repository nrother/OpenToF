// Demo code for Bluetooth Low Energy on the Seed Studio XIAO MG24 Sense Board
// make sure to select the Protocol stack "BLE (SiLabs)" in the Arduino IDE!
// based on an example from Seed Studio
#define RF_SW_PW_PIN PB5
#define RF_SW_PIN PB4

bool tof_notification_enabled = false;
bool battery_notification_enabled = false;

extern uint16_t tof_characteristic_handle, battery_characteristic_handle;
extern uint16_t last_tof;
extern uint8_t battery_level;

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, LED_BUILTIN_INACTIVE);
  Serial.begin(115200);
  Serial.println("OpenToF BLE Test\n");

  // configure the antenna
  pinMode(PB5, OUTPUT);
  pinMode(PB4, OUTPUT);
  digitalWrite(PB4, LOW);   // build-in antenna
  digitalWrite(PB5, HIGH);  // power on rf-switch

  // connect battery voltage to ADC
  pinMode(PD3, OUTPUT);
  digitalWrite(PD3, HIGH);

  delay(100);
}

void loop() {
  sl_status_t sc;
  if (tof_notification_enabled) {
    sc = sl_bt_gatt_server_write_attribute_value(tof_characteristic_handle, 0, sizeof(last_tof), (const uint8_t *)&last_tof);
    app_assert_status(sc);
    sc = sl_bt_gatt_server_notify_all(tof_characteristic_handle, sizeof(last_tof), (const uint8_t *)&last_tof);
    
    last_tof = 1000 + random(-300, 300); //DEBUG: Random ToF

    if (sc == SL_STATUS_OK) {
      Serial.println("Send ToF notification!");
    }
  }

  // read battery voltage
  // TODO: This produces bogus readings if not battery is connected
  int voltageValue = analogRead(PD4);
  float voltage = voltageValue * (2 * 3.3 / 4095.0);
  Serial.print("Battery voltage: ");
  Serial.print(voltage, 2);
  Serial.println(" V");
  // convert to battery level (0-100%)
  // note: This is a very crude formula, assuming a linear correlation between battery level and voltage
  // TODO: Find something better. This must be a solved problem.
  int level = round((voltage - 3.2) / (4.2 - 3.2) * 100);
  // check if the level changed
  if (level != battery_level) {
    battery_level = level;
    // always update value for manual reading by the client
    sc = sl_bt_gatt_server_write_attribute_value(battery_characteristic_handle, 0, sizeof(battery_level), (const uint8_t *)&battery_level);
    app_assert_status(sc);
    // send notification only if enabled
    if (battery_notification_enabled) {
      sc = sl_bt_gatt_server_notify_all(battery_characteristic_handle, sizeof(battery_level), (const uint8_t *)&battery_level);
      if (sc == SL_STATUS_OK) {
        Serial.println("Send battery notification!");
      }
    }
  }
  
  delay(1000);
}

// callback for the BLE stack
void sl_bt_on_event(sl_bt_msg_t *evt) {
  switch (SL_BT_MSG_ID(evt->header)) {
    case sl_bt_evt_system_boot_id:  // BLE stack ready
      {
        Serial.println("BLE stack booted");

        // Initialize the application specific GATT table
        ble_initialize_gatt_db();

        // Start advertising
        ble_start_advertising();
        Serial.println("BLE advertisement started");
      }
      break;

    case sl_bt_evt_connection_opened_id:  // client connected
      Serial.println("BLE connection opened");
      break;

    case sl_bt_evt_connection_closed_id:  // client disconnected
      Serial.println("BLE connection closed");
      // Restart the advertisement
      ble_start_advertising();
      Serial.println("BLE advertisement restarted");
      break;

    case sl_bt_evt_gatt_server_characteristic_status_id:  // GATT characteristic changed, update notifcations flags
      if (evt->data.evt_gatt_server_characteristic_status.characteristic == tof_characteristic_handle) {
        tof_notification_enabled = evt->data.evt_gatt_server_characteristic_status.client_config_flags & sl_bt_gatt_notification;
      } else if (evt->data.evt_gatt_server_characteristic_status.characteristic == battery_characteristic_handle) {
        battery_notification_enabled = evt->data.evt_gatt_server_characteristic_status.client_config_flags & sl_bt_gatt_notification;
      }
      break;

    default:  // unhandled event, ignored
      break;
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
