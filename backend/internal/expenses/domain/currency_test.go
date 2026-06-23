package domain

import "testing"

func TestSupportedCurrenciesMatchIOS(t *testing.T) {
	for _, code := range []string{"RUB", "EUR", "USD", "KZT", "JPY"} {
		if !IsSupportedCurrency(code) {
			t.Fatalf("expected %s to be supported", code)
		}
	}

	if IsSupportedCurrency("GBP") || IsSupportedCurrency("TRY") {
		t.Fatal("outdated currencies must not be supported")
	}
}
