const char device_name[] = "OpenToF Sensor";
const char manufacturer_name[] = "OpenToF Developers";
const char model_name[] = "XIAO MG24 Sense";
const char firmware_version[] = "v0.1-dev";
uint8_t battery_level = 0;
uint16_t last_tof = 0;
uint16_t gattdb_session_id;
uint16_t generic_access_service_handle, device_information_service_handle, battery_service_handle;
uint16_t custom_service_handle;
uint16_t tof_characteristic_handle, battery_characteristic_handle;

// Initialize the GATT database
void ble_initialize_gatt_db() {
  sl_status_t sc;
  // Create a new GATT database
  sc = sl_bt_gattdb_new_session(&gattdb_session_id);
  app_assert_status(sc);

  // 0x1800 GAP Service (required BLE service)
  // -------------------------------------------------------------------------------------
  const uint8_t generic_access_service_uuid[] = { 0x00, 0x18 };
  sc = sl_bt_gattdb_add_service(gattdb_session_id,
                                sl_bt_gattdb_primary_service,
                                SL_BT_GATTDB_ADVERTISED_SERVICE,
                                sizeof(generic_access_service_uuid),
                                generic_access_service_uuid,
                                &generic_access_service_handle);
  app_assert_status(sc);

  // 0x2A00 Device Name
  sc = ble_gatt_add_fixed_characteristic_16(0x2A00, gattdb_session_id, generic_access_service_handle, device_name, sizeof(device_name) - 1);
  app_assert_status(sc);

  // start the GAP service
  sc = sl_bt_gattdb_start_service(gattdb_session_id, generic_access_service_handle);
  app_assert_status(sc);

  // 0x180A Device Information Service
  // -------------------------------------------------------------------------------------
  const uint8_t device_information_service_uuid[] = { 0x0A, 0x18 };
  sc = sl_bt_gattdb_add_service(gattdb_session_id,
                                sl_bt_gattdb_primary_service,
                                SL_BT_GATTDB_ADVERTISED_SERVICE,
                                sizeof(device_information_service_uuid),
                                device_information_service_uuid,
                                &device_information_service_handle);
  app_assert_status(sc);

  // 0x2A29 Manufacturer Name
  sc = ble_gatt_add_fixed_characteristic_16(0x2A29, gattdb_session_id, device_information_service_handle, manufacturer_name, sizeof(manufacturer_name) - 1);
  app_assert_status(sc);

  // 0x2A24 Model Number
  sc = ble_gatt_add_fixed_characteristic_16(0x2A24, gattdb_session_id, device_information_service_handle, model_name, sizeof(model_name) - 1);
  app_assert_status(sc);

  // 0x2A25 Serial Number
  String serial_string = getDeviceUniqueIdStr();
  sc = ble_gatt_add_fixed_characteristic_16(0x2A25, gattdb_session_id, device_information_service_handle, serial_string.c_str(), serial_string.length());
  app_assert_status(sc);

  // 0x2A26 Firmware Version
  sc = ble_gatt_add_fixed_characteristic_16(0x2A26, gattdb_session_id, device_information_service_handle, firmware_version, sizeof(firmware_version) - 1);
  app_assert_status(sc);

  // start the Device Information service
  sc = sl_bt_gattdb_start_service(gattdb_session_id, device_information_service_handle);
  app_assert_status(sc);

  // 0x180F Battery Service
  // -------------------------------------------------------------------------------------
  const uint8_t battery_service_uuid[] = { 0x0F, 0x18 };
  sc = sl_bt_gattdb_add_service(gattdb_session_id,
                                sl_bt_gattdb_primary_service,
                                SL_BT_GATTDB_ADVERTISED_SERVICE,
                                sizeof(battery_service_uuid),
                                battery_service_uuid,
                                &battery_service_handle);
  app_assert_status(sc);

  // 0x2A19 Battery Level
  // TODO: This should support notify and we need to update this :)
  sl_bt_uuid_16_t battery_characteristic_uuid = { .data = { 0x19, 0x2A } };
  //sc = ble_gatt_add_fixed_characteristic_16(0x2A19, gattdb_session_id, battery_service_handle, (const char*)&battery_level, sizeof(battery_level));
  sc = sl_bt_gattdb_add_uuid16_characteristic(gattdb_session_id,
                                              battery_service_handle,
                                              SL_BT_GATTDB_CHARACTERISTIC_READ | SL_BT_GATTDB_CHARACTERISTIC_NOTIFY,
                                              0x00,
                                              0x00,
                                              battery_characteristic_uuid,
                                              sl_bt_gattdb_fixed_length_value,
                                              sizeof(battery_level),
                                              sizeof(battery_level),
                                              (const uint8_t*)&battery_level,
                                              &battery_characteristic_handle);
  app_assert_status(sc);

  // start the Battery service
  sc = sl_bt_gattdb_start_service(gattdb_session_id, battery_service_handle);
  app_assert_status(sc);

  // Custom service
  // UUID: 0b2aaecb-86e4-4453-b875-44f082813961
  // -------------------------------------------------------------------------------------
  const uuid_128 custom_service_uuid = {
    .data = {0x0b,0x2a,0xae,0xcb,0x86,0xe4,0x44,0x53,0xb8,0x75,0x44,0xf0,0x82,0x81,0x39,0x61}
  };
  sc = sl_bt_gattdb_add_service(gattdb_session_id,
                                sl_bt_gattdb_primary_service,
                                SL_BT_GATTDB_ADVERTISED_SERVICE,
                                sizeof(custom_service_uuid),
                                custom_service_uuid.data,
                                &custom_service_handle);
  app_assert_status(sc);

  // "Time of flight" characteristic
  // UUID: a407519d-e808-4d63-b719-5b95ddade041
  // TODO: Use indicate for ToF? Then the client has to ack them
  const uuid_128 tof_characteristic_uuid = {
    .data = {0xa4,0x07,0x51,0x9d,0xe8,0x08,0x4d,0x63,0xb7,0x19,0x5b,0x95,0xdd,0xad,0xe0,0x41}
  };
  sc = sl_bt_gattdb_add_uuid128_characteristic(gattdb_session_id,
                                               custom_service_handle,
                                               SL_BT_GATTDB_CHARACTERISTIC_READ | SL_BT_GATTDB_CHARACTERISTIC_NOTIFY,
                                               0x00,
                                               0x00,
                                               tof_characteristic_uuid,
                                               sl_bt_gattdb_fixed_length_value,
                                               sizeof(last_tof),
                                               sizeof(last_tof),
                                               (const uint8_t*)&last_tof,
                                               &tof_characteristic_handle);

  // Start custom BLE service
  sc = sl_bt_gattdb_start_service(gattdb_session_id, custom_service_handle);
  app_assert_status(sc);

  // Commit the GATT DB changes
  sc = sl_bt_gattdb_commit(gattdb_session_id);
  app_assert_status(sc);
}

// add a characteristic with a 16-bit UUID and a fixed (read-only) value
sl_status_t ble_gatt_add_fixed_characteristic_16(const uint16_t uuid, const uint16_t gattdb_session_id, uint16_t service_handle, const char* value, size_t value_length)
{
  sl_bt_uuid_16_t characteristic_uuid = { .data = { (uint8_t)(uuid & 0xFF), (uint8_t)(uuid >> 8) } };
  uint16_t characteristic_handle;
  return sl_bt_gattdb_add_uuid16_characteristic(gattdb_session_id,
                                              service_handle,
                                              SL_BT_GATTDB_CHARACTERISTIC_READ,
                                              0x00,
                                              0x00,
                                              characteristic_uuid,
                                              sl_bt_gattdb_fixed_length_value,
                                              value_length,
                                              value_length,
                                              (const uint8_t*)value,
                                              &characteristic_handle);
}