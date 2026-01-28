#ifndef VIDVIZ_DART_API_DL_H_
#define VIDVIZ_DART_API_DL_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef int64_t Dart_Port;

typedef enum {
  Dart_CObject_kNull = 0,
  Dart_CObject_kBool = 1,
  Dart_CObject_kInt32 = 2,
  Dart_CObject_kInt64 = 3,
  Dart_CObject_kDouble = 4,
  Dart_CObject_kString = 5,
  Dart_CObject_kArray = 6,
  Dart_CObject_kTypedData = 7,
  Dart_CObject_kExternalTypedData = 8,
  Dart_CObject_kSendPort = 9,
  Dart_CObject_kCapability = 10,
} Dart_CObject_Type;

typedef enum {
  Dart_TypedData_kByteData = 0,
  Dart_TypedData_kInt8 = 1,
  Dart_TypedData_kUint8 = 2,
  Dart_TypedData_kUint8Clamped = 3,
  Dart_TypedData_kInt16 = 4,
  Dart_TypedData_kUint16 = 5,
  Dart_TypedData_kInt32 = 6,
  Dart_TypedData_kUint32 = 7,
  Dart_TypedData_kInt64 = 8,
  Dart_TypedData_kUint64 = 9,
  Dart_TypedData_kFloat32 = 10,
  Dart_TypedData_kFloat64 = 11,
  Dart_TypedData_kInt32x4 = 12,
  Dart_TypedData_kFloat32x4 = 13,
  Dart_TypedData_kFloat64x2 = 14,
} Dart_TypedData_Type;

typedef struct {
  Dart_Port id;
  Dart_Port origin_id;
} Dart_SendPort;

typedef struct {
  int64_t id;
} Dart_CObject_Capability;

typedef struct {
  Dart_TypedData_Type type;
  int64_t length;
  uint8_t* values;
} Dart_CObject_TypedData;

typedef struct {
  Dart_TypedData_Type type;
  int64_t length;
  uint8_t* data;
  void* peer;
  void (*callback)(void* peer);
} Dart_CObject_ExternalTypedData;

typedef struct {
  int64_t length;
  struct _Dart_CObject** values;
} Dart_CObject_Array;

typedef union {
  bool as_bool;
  int32_t as_int32;
  int64_t as_int64;
  double as_double;
  const char* as_string;
  Dart_CObject_Array as_array;
  Dart_CObject_TypedData as_typed_data;
  Dart_CObject_ExternalTypedData as_external_typed_data;
  Dart_SendPort as_send_port;
  Dart_CObject_Capability as_capability;
} Dart_CObject_Value;

typedef struct _Dart_CObject {
  Dart_CObject_Type type;
  Dart_CObject_Value value;
} Dart_CObject;

typedef bool (*Dart_PostCObjectType)(Dart_Port port_id, Dart_CObject* message);

int Dart_InitializeApiDL(void* data);
bool Dart_PostCObject_DL(Dart_Port port_id, Dart_CObject* message);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // VIDVIZ_DART_API_DL_H_
