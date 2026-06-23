package domain

import "testing"

func TestEqualSplitDistributesRemainderDeterministically(t *testing.T) {
	shares, err := EqualSplit(100, 3)
	if err != nil {
		t.Fatal(err)
	}

	expected := []int64{34, 33, 33}
	for index := range expected {
		if shares[index] != expected[index] {
			t.Fatalf("expected %v, got %v", expected, shares)
		}
	}
}

func TestEqualSplitRejectsInvalidInput(t *testing.T) {
	if _, err := EqualSplit(0, 3); err == nil {
		t.Fatal("expected error")
	}
}
