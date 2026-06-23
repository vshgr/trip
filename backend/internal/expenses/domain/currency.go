package domain

type Currency struct {
	Code           string
	FractionDigits int
}

var SupportedCurrencies = map[string]Currency{
	"RUB": {Code: "RUB", FractionDigits: 2},
	"EUR": {Code: "EUR", FractionDigits: 2},
	"USD": {Code: "USD", FractionDigits: 2},
	"KZT": {Code: "KZT", FractionDigits: 2},
	"JPY": {Code: "JPY", FractionDigits: 0},
}

func IsSupportedCurrency(code string) bool {
	_, ok := SupportedCurrencies[code]
	return ok
}
