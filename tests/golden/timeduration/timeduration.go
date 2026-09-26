// time.Duration (shim parcial): String/Seconds/Round/Truncate/Abs como o Go e
// o Config de google.golang.org/grpc/backoff.
package main

import (
	"fmt"
	"math"
	"time"
)

// Config de google.golang.org/grpc/backoff.
type Config struct {
	BaseDelay  time.Duration
	Multiplier float64
	Jitter     float64
	MaxDelay   time.Duration
}

var DefaultConfig = Config{
	BaseDelay:  1.0 * time.Second,
	Multiplier: 1.6,
	Jitter:     0.2,
	MaxDelay:   120 * time.Second,
}

func backoff(c Config, retries int) time.Duration {
	if retries == 0 {
		return c.BaseDelay
	}
	b, max := float64(c.BaseDelay), float64(c.MaxDelay)
	for b < max && retries > 0 {
		b *= c.Multiplier
		retries--
	}
	if b > max {
		b = max
	}
	return time.Duration(b)
}

func main() {
	ds := []time.Duration{0, 1, 999, 1000, 1500, time.Microsecond * 999, time.Millisecond, 1500 * time.Millisecond,
		-time.Second, 90 * time.Minute, 72*time.Hour + 3*time.Minute + time.Second/2, math.MinInt64, math.MaxInt64, -1}
	for _, d := range ds {
		fmt.Println(d, d.Nanoseconds(), d.Microseconds(), d.Milliseconds(), d.Seconds(), d.Minutes(), d.Hours(), d.Abs())
	}
	for _, m := range []time.Duration{0, time.Second, 7 * time.Millisecond, time.Hour} {
		d := 3*time.Hour + 1234567891
		fmt.Println(d.Round(m), d.Truncate(m), (-d).Round(m), (-d).Truncate(m))
	}
	fmt.Println(time.Duration(math.MaxInt64).Round(time.Hour), time.Duration(math.MinInt64).Round(time.Hour))
	for i := 0; i < 4; i++ {
		fmt.Print(backoff(DefaultConfig, i*5), " ")
	}
	fmt.Printf("\n%v %s %d %T\n", DefaultConfig, time.Minute, time.Millisecond, time.Second)
}
