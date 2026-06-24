package domain

import "errors"

var ErrInvalidSplit = errors.New("amount must be positive and participant count must be greater than zero")

func EqualSplit(amountMinor int64, participantCount int) ([]int64, error) {
	if amountMinor <= 0 || participantCount <= 0 {
		return nil, ErrInvalidSplit
	}

	shares := make([]int64, participantCount)
	base := amountMinor / int64(participantCount)
	remainder := amountMinor % int64(participantCount)
	for index := range shares {
		shares[index] = base
		if int64(index) < remainder {
			shares[index]++
		}
	}
	return shares, nil
}
