package system

import "testing"

func TestResolveKeyboardKey(t *testing.T) {
	testCases := []struct {
		name         string
		input        string
		wantKey      string
		wantVirtual  uint16
		wantExtended bool
		wantErr      bool
	}{
		{name: "letter", input: "a", wantKey: "a", wantVirtual: 'A'},
		{name: "digit", input: "5", wantKey: "5", wantVirtual: '5'},
		{name: "enter", input: "enter", wantKey: "enter", wantVirtual: vkReturn},
		{name: "left arrow", input: "left", wantKey: "left", wantVirtual: vkLeft, wantExtended: true},
		{name: "function key", input: "F5", wantKey: "f5", wantVirtual: vkF5},
		{name: "meta alias", input: "win", wantKey: "win", wantVirtual: vkLeftWin},
		{name: "invalid", input: "semicolon", wantErr: true},
	}

	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			gotKey, gotSpec, err := resolveKeyboardKey(testCase.input)
			if testCase.wantErr {
				if err == nil {
					t.Fatalf("resolveKeyboardKey(%q) error = nil, want error", testCase.input)
				}
				return
			}
			if err != nil {
				t.Fatalf("resolveKeyboardKey(%q) error = %v", testCase.input, err)
			}
			if gotKey != testCase.wantKey {
				t.Fatalf("resolveKeyboardKey(%q) key = %q, want %q", testCase.input, gotKey, testCase.wantKey)
			}
			if gotSpec.VirtualKey != testCase.wantVirtual {
				t.Fatalf("resolveKeyboardKey(%q) virtual = %d, want %d", testCase.input, gotSpec.VirtualKey, testCase.wantVirtual)
			}
			if gotSpec.Extended != testCase.wantExtended {
				t.Fatalf("resolveKeyboardKey(%q) extended = %t, want %t", testCase.input, gotSpec.Extended, testCase.wantExtended)
			}
		})
	}
}
