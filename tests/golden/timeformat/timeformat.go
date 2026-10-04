// Shim time: interpretador de layouts (Format/AppendFormat/Parse/
// ParseInLocation), as constantes de layout, *time.ParseError e o texto de
// MarshalText/MarshalJSON/MarshalBinary. Repro de
// TODO/P1-shim-time-layout.md.
package main

import (
	"errors"
	"fmt"
	"time"
)

var layouts = []string{
	time.Layout, time.ANSIC, time.UnixDate, time.RubyDate, time.RFC822, time.RFC822Z,
	time.RFC850, time.RFC1123, time.RFC1123Z, time.RFC3339, time.RFC3339Nano, time.Kitchen,
	time.Stamp, time.StampMilli, time.StampMicro, time.StampNano, time.DateTime,
	time.DateOnly, time.TimeOnly,
	"2006-01-02T15:04:05.000Z0700",
	"January 2, 2006 at 3:04pm (MST) Z07 -07 Z070000 -070000 Z07:00:00 -07:00:00",
	"Monday Mon Jan January 1 01 2 _2 02 __2 002 06 2006 _2006 15 3 03 4 04 5 05 PM pm",
	"15:04:05,000 15:04:05,999 .9 .99 .000000 .999999999 ,9999",
	"Month Mondays Janet 1.5 x.0y",
	"",
}

func show(t time.Time) {
	for _, l := range layouts {
		fmt.Printf("%q => %q\n", l, t.Format(l))
	}
	b := t.AppendFormat([]byte("pre:"), time.RFC3339Nano)
	fmt.Println(string(b), string(t.AppendFormat(nil, "Jan _2")))
	txt, err := t.MarshalText()
	fmt.Println(string(txt), err)
	js, err := t.MarshalJSON()
	fmt.Println(string(js), err)
	bin, err := t.MarshalBinary()
	fmt.Println(bin, err)
	var back time.Time
	fmt.Println(back.UnmarshalBinary(bin), back.Equal(t), back.Format(time.RFC3339Nano))
	fmt.Println(t.GoString())
}

func parse(layout, value string) {
	t, err := time.Parse(layout, value)
	if err != nil {
		fmt.Printf("Parse(%q, %q): erro %v\n", layout, value, err)
		var pe *time.ParseError
		if errors.As(err, &pe) {
			fmt.Printf("  %q %q %q %q %q\n", pe.Layout, pe.Value, pe.LayoutElem, pe.ValueElem, pe.Message)
		}
		return
	}
	name, off := t.Zone()
	fmt.Printf("Parse(%q, %q) = %v | %d %d | %q %d | %s\n", layout, value, t, t.Unix(), t.Nanosecond(), name, off, t.Location())
}

func main() {
	east := time.FixedZone("EST5", -5*3600)
	odd := time.FixedZone("", 5*3600+30*60+15)
	neg := time.FixedZone("NEG", -(9*3600 + 30*60))
	times := []time.Time{
		time.Unix(0, 0).UTC(),
		time.Date(2009, time.November, 10, 23, 4, 5, 123456789, time.UTC),
		time.Date(2024, time.February, 29, 0, 7, 9, 1000, east),
		time.Date(1999, time.December, 31, 12, 0, 0, 500000000, odd),
		time.Date(7, time.July, 4, 9, 30, 0, 0, neg),
		time.Date(-44, time.March, 15, 13, 0, 0, 0, time.UTC),
		time.Date(12345, time.May, 5, 5, 5, 5, 5, time.UTC),
		{},
	}
	for _, t := range times {
		show(t)
	}

	// Erros de Marshal (ano fora de [0,9999] e fuso >= 24h).
	far := time.Date(10000, 1, 1, 0, 0, 0, 0, time.UTC)
	_, err := far.MarshalJSON()
	fmt.Println(err)
	_, err = far.MarshalText()
	fmt.Println(err)
	_, err = far.AppendText(nil)
	fmt.Println(err)
	_, err = time.Date(2000, 1, 1, 0, 0, 0, 0, time.FixedZone("X", 25*3600)).MarshalJSON()
	fmt.Println(err)
	out, err := time.Date(2000, 1, 1, 0, 0, 0, 0, time.UTC).AppendText([]byte("t="))
	fmt.Println(string(out), err)

	// Parse: sucessos.
	parse(time.RFC3339, "2006-01-02T15:04:05Z")
	parse(time.RFC3339, "2006-01-02T15:04:05.123+07:00")
	parse(time.RFC3339, "2006-01-02T15:04:05,5-03:30")
	parse(time.RFC3339Nano, "2024-02-29T23:59:59.999999999999-00:00")
	parse(time.RFC3339, "2006-01-02T15:04:05+00:00")
	parse(time.RFC1123, "Mon, 02 Jan 2006 15:04:05 MST")
	parse(time.RFC1123, "Mon, 02 Jan 2006 15:04:05 UTC")
	parse(time.RFC1123, "Mon, 02 Jan 2006 15:04:05 GMT+3")
	parse(time.RFC1123, "Mon, 02 Jan 2006 15:04:05 GMT-11")
	parse(time.RFC1123, "Mon, 02 Jan 2006 15:04:05 ChST")
	parse(time.RFC1123, "Mon, 02 Jan 2006 15:04:05 +03")
	parse(time.RFC1123Z, "Tue, 10 Nov 2009 23:00:00 -0800")
	parse(time.RFC822Z, "10 Nov 69 23:00 +0000")
	parse(time.RFC822, "10 Nov 68 23:00 PDT")
	parse(time.RFC850, "Tuesday, 10-Nov-09 23:00:00 CEST")
	parse(time.ANSIC, "Tue Nov  3 23:00:00 2009")
	parse(time.UnixDate, "Tue Nov 10 23:00:00 WITA 2009")
	parse(time.RubyDate, "Tue Nov 10 23:00:00 +0530 2009")
	parse(time.Kitchen, "3:04PM")
	parse(time.Kitchen, "12:00AM")
	parse(time.Kitchen, "12:30PM")
	parse("3:04pm", "11:59pm")
	parse(time.StampMicro, "Feb  3 04:05:06.123456")
	parse(time.DateTime, "2023-10-04 08:09:10.75")
	parse(time.DateOnly, "2023-10-04")
	parse(time.TimeOnly, "23:59:59")
	parse("2006 002", "2024 060")
	parse("2006 __2", "2023  60")
	parse("2006 002 Jan 02", "2024 366 Dec 31")
	parse("January 2, 2006", "february 28, 2001")
	parse("Z07:00:00 2006", "-01:02:03 2000")
	parse("Z070000 2006", "+010203 2000")
	parse("-07 2006", "+05 2000")
	parse("Z07 2006", "Z 2000")
	parse("2006-01-02 15:04:05.000", "2001-02-03 04:05:06.789")
	parse("2006-01-02 15:04:05.999", "2001-02-03 04:05:06")
	parse("2006-01-02 15:04:05,000", "2001-02-03 04:05:06,001")
	parse("_2006", "_2001")
	parse("06", "70")
	parse("Mon Jan 2", "fri Mar 7")

	// Parse: erros.
	parse(time.RFC3339, "2006-01-02T15:04:05")
	parse(time.RFC3339, "2006-01-02 15:04:05Z")
	parse(time.RFC3339, "2006-13-02T15:04:05Z")
	parse(time.RFC3339, "2006-02-30T15:04:05Z")
	parse(time.RFC3339, "2006-01-02T25:04:05Z")
	parse(time.RFC3339, "2006-01-02T15:04:05+25:00")
	parse(time.RFC3339, "2006-01-02T15:04:05Zjunk")
	parse(time.DateOnly, "2006-1-02")
	parse(time.DateOnly, "06-01-02")
	parse(time.TimeOnly, "23:59:60")
	parse(time.Kitchen, "13:04PM")
	parse(time.Kitchen, "3:04XM")
	parse(time.TimeOnly, "12:61:00")
	parse(time.RFC1123, "Mon, 02 Jan 2006 15:04:05 mst")
	parse(time.RFC1123, "Xyz, 02 Jan 2006 15:04:05 MST")
	parse(time.RFC1123Z, "Mon, 02 Jan 2006 15:04:05 0700")
	parse(time.StampMilli, "Jan  2 15:04:05.12")
	parse("2006 002", "2023 366")
	parse("2006 002 Jan", "2024 060 Mar")
	parse("2006 002 _2", "2024 061 2")
	parse("2006-01-02", "2006-01-02 extra")
	parse("2006-01-02", "")
	parse("", "x")
	parse("Jan", "Ja\xffn")
	parse("15:04 -07:00", "10:00 +07-00")
	parse("15:04 -0700", "10:00 +2500")
	parse("15:04 -0700", "10:00 +0061")
	parse("15:04 -070000", "10:00 +000061")
	parse("15:04:05", "10:00:5x")

	// ParseInLocation: sem zona usa loc; com offset igual ao de loc usa loc.
	loc := time.FixedZone("BRT", -3*3600)
	for _, v := range []string{"2023-10-04 10:00:00", "2023-10-04 10:00:00 -0300", "2023-10-04 10:00:00 +0100", "2023-10-04 10:00:00 BRT"} {
		layout := "2006-01-02 15:04:05"
		if len(v) > len(layout) {
			if v[len(v)-1] == 'T' {
				layout += " MST"
			} else {
				layout += " -0700"
			}
		}
		t, err := time.ParseInLocation(layout, v, loc)
		fmt.Println(t, err, t.Location(), t.Location() == loc)
	}
	t, err := time.ParseInLocation(time.RFC3339, "2023-10-04T10:00:00-03:00", loc)
	fmt.Println(t, err, t.Location() == loc)
	t, err = time.ParseInLocation(time.RFC3339, "2023-10-04T10:00:00Z", loc)
	fmt.Println(t, err, t.Location() == time.UTC)

	// UnmarshalJSON/UnmarshalText e os erros.
	for _, s := range []string{`"2023-10-04T10:00:00.5+02:00"`, `null`, `2023`, `"2023-10-04"`, `"x`} {
		var u time.Time
		err := u.UnmarshalJSON([]byte(s))
		fmt.Println(u, err)
	}
	for _, s := range []string{"2023-10-04T10:00:00Z", "2023-10-04T10:00:00.123456789-01:00", "bad"} {
		var u time.Time
		err := u.UnmarshalText([]byte(s))
		fmt.Println(u, err)
	}
	var u time.Time
	fmt.Println(u.UnmarshalBinary(nil), u.UnmarshalBinary([]byte{9}), u.UnmarshalBinary([]byte{1, 2}))

	// Ida e volta pelo Local (= UTC no shim, TZ=UTC no Go).
	l, _ := time.Parse("2006-01-02 -0700", "2020-05-06 +0000")
	fmt.Println(l, l.Location(), l.Location() == time.Local, time.Local, time.UTC)
	fmt.Println(time.Date(2020, 1, 2, 3, 4, 5, 6, time.Local).GoString())
	fmt.Println(time.Date(2020, 1, 2, 3, 4, 5, 6, east).GoString(), time.Unix(1e9, 0).IsDST())
}
