import 'package:flutter_test/flutter_test.dart';

import 'package:gpu_monitor/screens/home_screen.dart';

void main() {
  test('groups all GPU indices by host', () {
    expect(
      formatGpuGroups({
        'SIG-4090': {7, 1, 3, 0, 6, 2, 5, 4},
      }),
      'SIG-4090:0,1,2,3,4,5,6,7',
    );
  });

  test('keeps different hosts separate', () {
    expect(
      formatGpuGroups({
        'z-host': {2, 0},
        'a-host': {1},
      }),
      'a-host:1, z-host:0,2',
    );
  });
}
