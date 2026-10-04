//go:build ignore

// Oráculo do shim `time` (Time, Date, Unix, aritmética, Month/Weekday,
// ParseDuration, Format/Parse/ParseInLocation com layout): imprime em JSON as entradas e a saída do Go. Rodar com
// TZ=UTC (o `Local` do shim é o do Go com TZ=UTC). Inteiros vão como string
// (o JSON do JS perderia precisão acima de 2^53); entradas do ParseDuration
// em hex (podem ter UTF-8 inválido).
package main

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"math"
	"os"
	"strconv"
	"time"
)

func describe(t time.Time) []string {
	y, m, d := t.Date()
	h, mi, s := t.Clock()
	iy, iw := t.ISOWeek()
	zn, zo := t.Zone()
	return []string{
		t.String(),
		j(t.Unix(), t.UnixNano(), t.UnixMilli(), t.UnixMicro()),
		j(y, int(m), d, m.String(), t.Year(), int(t.Month()), t.Day()),
		j(h, mi, s, t.Hour(), t.Minute(), t.Second(), t.Nanosecond()),
		j(t.Weekday().String(), t.YearDay(), iy, iw),
		j(zn, zo, t.Location().String(), t.IsZero()),
	}
}

// j junta os operandos com um espaço (o fmt.Sprint só põe espaço entre
// operandos que não são string).
func j(args ...any) string {
	out := ""
	for i, a := range args {
		if i > 0 {
			out += " "
		}
		out += fmt.Sprint(a)
	}
	return out
}

func errText(err error) string {
	if err == nil {
		return "<nil>"
	}
	return err.Error()
}

func i64(s []int64) []string {
	out := make([]string, len(s))
	for i, v := range s {
		out[i] = strconv.FormatInt(v, 10)
	}
	return out
}

type zone struct {
	Name   string `json:"name"`
	Offset int    `json:"offset"`
}

func loc(z *zone) *time.Location {
	if z == nil {
		return time.UTC
	}
	return time.FixedZone(z.Name, z.Offset)
}

func main() {
	res := map[string]any{}

	// Unix(sec, nsec): Local (= UTC aqui), .UTC() e .In(zona fixa).
	secs := []int64{0, 1, -1, 59, 86399, 86400, -86401, 951782400, 1709164800,
		1234567890, 253402300799, 253402300800, -62135596800, -62135596801,
		-62198755200, -62167219200, 1 << 40, -(1 << 40), 1 << 50, -(1 << 50),
		9223372036, -9223372036, math.MaxInt64, math.MinInt64,
		math.MaxInt64 - 62135596800, math.MinInt64 + 62135596800}
	nsecs := []int64{0, 1, 999999999, 1000000000, -1, -1000000001, 123456789,
		1 << 62, -(1 << 62), math.MaxInt64, math.MinInt64}
	fz := time.FixedZone("BRT", -3*3600)
	var unixOut []string
	for _, s := range secs {
		for _, n := range nsecs {
			t := time.Unix(s, n)
			unixOut = append(unixOut, describe(t)...)
			unixOut = append(unixOut, describe(t.UTC())...)
			unixOut = append(unixOut, describe(t.In(fz))...)
			unixOut = append(unixOut, j(t == t.UTC(), t.UTC() == t.UTC(), t.Location() == time.Local,
				t.UTC().Location() == time.UTC, t.Equal(t.In(fz))))
		}
	}
	res["secs"], res["nsecs"], res["unix"] = i64(secs), i64(nsecs), unixOut
	for _, ms := range []int64{0, 1, -1, 1500, -1500, 1 << 53, -(1 << 53), math.MaxInt64, math.MinInt64} {
		res["milli"] = append(asList(res["milli"]), strconv.FormatInt(ms, 10))
		res["milliOut"] = append(asList(res["milliOut"]), describe(time.UnixMilli(ms).UTC())[0], describe(time.UnixMicro(ms).UTC())[0])
	}

	// Date(...) com normalização e zonas fixas.
	dates := [][]int64{{2024, 2, 29, 12, 30, 45, 5}, {2023, 2, 29, 0, 0, 0, 0}, {2024, 13, 1, 0, 0, 0, 0},
		{2024, 0, 0, 0, 0, 0, 0}, {2024, 1, 1, 25, 61, 61, 1000000005}, {2024, -25, -400, -30, -70, -70, -1},
		{1, 1, 1, 0, 0, 0, 0}, {0, 1, 1, 0, 0, 0, 0}, {-1000, 7, 4, 1, 2, 3, 4}, {1000000, 12, 31, 23, 59, 59, 999999999},
		{-1000000, 3, 1, 0, 0, 0, 0}, {1970, 1, 1, 0, 0, 0, 0}, {2000, 12, 31, 0, 0, 0, 0}, {1900, 3, 1, 0, 0, 0, 0},
		{2100, 2, 28, 0, 0, 0, 0}, {2400, 2, 29, 0, 0, 0, 0}, {2021, 1, 3, 0, 0, 0, 0}, {2020, 12, 31, 0, 0, 0, 0},
		{2026, 10, 2, 9, 8, 7, 600}}
	zones := []*zone{nil, {"BRT", -3 * 3600}, {"", 5*3600 + 1800}, {"X", 45}, {"", -59}, {"", -(14*3600 + 30*60)}}
	var dateOut []string
	for _, a := range dates {
		for _, z := range zones {
			t := time.Date(int(a[0]), time.Month(a[1]), int(a[2]), int(a[3]), int(a[4]), int(a[5]), int(a[6]), loc(z))
			dateOut = append(dateOut, describe(t)...)
		}
	}
	var dateIn [][]string
	for _, a := range dates {
		dateIn = append(dateIn, i64(a))
	}
	res["dates"], res["zones"], res["date"] = dateIn, zones, dateOut

	// Aritmética: Add/Sub/comparações/AddDate/Truncate/Round.
	bases := []time.Time{time.Unix(0, 0), time.Unix(1709164800, 123456789), time.Unix(-62135596801, 999999999),
		time.Date(2024, 1, 31, 23, 59, 59, 999999999, time.UTC), time.Date(-5, 3, 1, 0, 0, 0, 1, fz),
		time.Unix(253402300799, 500000000).UTC(), time.Time{}}
	durs := []int64{0, 1, -1, 7, 999999999, 1000000000, 1500000000, -1500000000, 3000000001, 60e9, 3600e9, 86400e9,
		7 * 86400e9, 1 << 62, -(1 << 62), math.MaxInt64, math.MinInt64}
	var arith []string
	for _, b := range bases {
		for _, d := range durs {
			dd := time.Duration(d)
			a := b.Add(dd)
			arith = append(arith, a.String(), b.Truncate(dd).String(), b.Round(dd).String())
			sub := a.Sub(b)
			arith = append(arith, j(int64(sub), sub.String(), b.Sub(a).String(),
				a.Before(b), a.After(b), a.Equal(b), a.Compare(b), b.Compare(a), a == b))
		}
		for _, u := range bases {
			s := b.Sub(u)
			arith = append(arith, j(int64(s), b.Before(u), b.After(u), b.Equal(u), b.Compare(u), b == u))
		}
		for _, ymd := range [][3]int{{0, 0, 0}, {1, 0, 0}, {0, 1, 0}, {0, 0, 1}, {-1, -13, 400}, {0, 1, 30}, {1000, 0, -1}} {
			arith = append(arith, b.AddDate(ymd[0], ymd[1], ymd[2]).String())
		}
	}
	var baseIn [][]string
	for _, b := range bases {
		// sec/nsec Unix + zona: suficiente para reconstruir a base.
		zn, zo := b.Zone()
		name := "UTC"
		if b.Location() == time.Local {
			name = "Local"
		} else if b.Location() != time.UTC {
			name = "fixed"
		}
		baseIn = append(baseIn, []string{strconv.FormatInt(b.Unix(), 10), strconv.Itoa(b.Nanosecond()), name, zn, strconv.Itoa(zo)})
	}
	res["bases"], res["durs"], res["arith"] = baseIn, i64(durs), arith

	// Month/Weekday.
	var mw []string
	for i := -1; i <= 14; i++ {
		mw = append(mw, time.Month(i).String(), time.Weekday(i).String())
	}
	mw = append(mw, time.Month(1<<40+1).String(), time.Weekday(-(1 << 40)).String())
	res["monthWeekday"] = mw

	// ParseDuration.
	pds := []string{"0", "-0", "+0", "1s", "1.5h", "-1.5h", "2h45m", "300ms", ".5s", "5.s", ".s", "", "-", "+", "1",
		"1x", "1µs", "1μs", "1us", "1ns", "9223372036854775807ns", "9223372036854775808ns", "-9223372036854775808ns",
		"-9223372036854775809ns", "9223372036s", "9223372037s", "2562047h", "2562048h", "0.000000001s", "1.0000000001s",
		"0.3333333333333333333h", "1e3s", "1h1h", "\xff s", "1\xffs", "1.123456789012345678901234567890s",
		"1.9999999999999999999999h", "00001s", ".1.2s", "1h-2m", "1s\x01", "1\"s", "1\\s", "1日", "3m0.5s", "-.5ms",
		"2562047h47m16.854775807s", "2562047h47m16.854775808s", "-2562047h47m16.854775808s", "0.9999999999999999999999999ns",
		"18446744073709551616ns", "1.5.s", "5m.", "99999999999999999999h"}
	var pdIn, pdOut []string
	for _, s := range pds {
		d, err := time.ParseDuration(s)
		pdIn = append(pdIn, hex.EncodeToString([]byte(s)))
		pdOut = append(pdOut, j(int64(d), d.String(), hex.EncodeToString([]byte(errText(err)))))
	}
	res["pdIn"], res["pdOut"] = pdIn, pdOut

	// Format sobre datas×zonas; Parse/ParseInLocation do texto formatado e
	// Parse do texto sem o último byte (erros), numa data a cada 4.
	layouts := []string{time.Layout, time.ANSIC, time.UnixDate, time.RubyDate, time.RFC822, time.RFC822Z,
		time.RFC850, time.RFC1123, time.RFC1123Z, time.RFC3339, time.RFC3339Nano, time.Kitchen,
		time.StampNano, time.DateTime, "2006-01-02T15:04:05.000Z0700", "Z07 -07 Z070000 -070000 Z07:00:00 -07:00:00 MST",
		"Monday Mon January Jan 1 01 2 _2 02 __2 002 06 2006 15 3 03 4 04 5 05 PM pm .0 .99 ,999999",
		"2006 002 15:04:05,000000000 -07:00"}
	var fmtOut, parseOut []string
	describeParse := func(p time.Time, err error) string {
		zn, zo := p.Zone()
		return j(p.String(), zn, zo, p.Location() == time.Local, p.Location() == fz, errText(err))
	}
	for di, a := range dates {
		for _, z := range zones {
			t := time.Date(int(a[0]), time.Month(a[1]), int(a[2]), int(a[3]), int(a[4]), int(a[5]), int(a[6]), loc(z))
			for _, l := range layouts {
				s := t.Format(l)
				fmtOut = append(fmtOut, s)
				if di%4 != 0 {
					continue
				}
				p, err := time.Parse(l, s)
				parseOut = append(parseOut, describeParse(p, err))
				p, err = time.ParseInLocation(l, s, fz)
				parseOut = append(parseOut, describeParse(p, err))
				p, err = time.Parse(l, s[:len(s)-1])
				parseOut = append(parseOut, describeParse(p, err))
			}
		}
	}
	res["layouts"], res["format"], res["parse"] = layouts, fmtOut, parseOut

	enc := json.NewEncoder(os.Stdout)
	if err := enc.Encode(res); err != nil {
		panic(err)
	}
}

func asList(v any) []string {
	if v == nil {
		return nil
	}
	return v.([]string)
}
