enum RemoteCommandType { hex, text }

const loraTargetAddress = 1;

class RemoteCommand {
  const RemoteCommand({
    required this.name,
    required this.payload,
    required this.expectedResponse,
    this.type = RemoteCommandType.hex,
  });

  final String name;
  final String payload;
  final String expectedResponse;
  final RemoteCommandType type;
}

RemoteCommand loraAtCommand({
  required String name,
  required String hexPayload,
  required String expectedResponse,
}) {
  final dataLength = hexPayload.length;

  return RemoteCommand(
    name: name,
    payload: 'AT+SEND=$loraTargetAddress,$dataLength,$hexPayload',
    expectedResponse: expectedResponse,
    type: RemoteCommandType.text,
  );
}

final numberCommands = <RemoteCommand>[
  loraAtCommand(
    name: '1',
    hexPayload: '7B 04 01 C2 D9 7D',
    expectedResponse: 'KEY 1 OK',
  ),
  loraAtCommand(
    name: '2',
    hexPayload: '7B 04 02 82 D8 7D',
    expectedResponse: 'KEY 2 OK',
  ),
  loraAtCommand(
    name: '3',
    hexPayload: '7B 04 03 43 18 7D',
    expectedResponse: 'KEY 3 OK',
  ),
  loraAtCommand(
    name: '4',
    hexPayload: '7B 04 04 02 DA 7D',
    expectedResponse: 'KEY 4 OK',
  ),
  loraAtCommand(
    name: '5',
    hexPayload: '7B 04 05 C3 1A 7D',
    expectedResponse: 'KEY 5 OK',
  ),
  loraAtCommand(
    name: '6',
    hexPayload: '7B 04 06 83 1B 7D',
    expectedResponse: 'KEY 6 OK',
  ),
  loraAtCommand(
    name: '7',
    hexPayload: '7B 04 07 42 DB 7D',
    expectedResponse: 'KEY 7 OK',
  ),
  loraAtCommand(
    name: '8',
    hexPayload: '7B 04 08 02 DF 7D',
    expectedResponse: 'KEY 8 OK',
  ),
];

final modeCommands = <RemoteCommand>[
  loraAtCommand(
    name: 'AUTO',
    hexPayload: '7B 02 01 C1 79 7D',
    expectedResponse: 'AUTO OK',
  ),
  loraAtCommand(
    name: 'MANUAL',
    hexPayload: '7B 02 02 81 78 7D',
    expectedResponse: 'MANUAL OK',
  ),
];
