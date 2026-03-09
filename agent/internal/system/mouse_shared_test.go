package system

import "testing"

func TestNormalizeMouseButton(t *testing.T) {
	testCases := []struct {
		name    string
		input   string
		want    string
		wantErr bool
	}{
		{name: "default", input: "", want: "left"},
		{name: "left", input: "left", want: "left"},
		{name: "right", input: "right", want: "right"},
		{name: "middle", input: "middle", want: "middle"},
		{name: "invalid", input: "side", wantErr: true},
	}

	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			got, err := normalizeMouseButton(testCase.input)
			if testCase.wantErr {
				if err == nil {
					t.Fatalf("normalizeMouseButton(%q) error = nil, want error", testCase.input)
				}
				return
			}
			if err != nil {
				t.Fatalf("normalizeMouseButton(%q) error = %v", testCase.input, err)
			}
			if got != testCase.want {
				t.Fatalf("normalizeMouseButton(%q) = %q, want %q", testCase.input, got, testCase.want)
			}
		})
	}
}
