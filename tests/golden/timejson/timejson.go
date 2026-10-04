// Shim time + encoding/json + reflect: time.Time (struct de campos não
// exportados com MarshalJSON/UnmarshalJSON), *time.Time, time.Duration,
// time.Month e time.Weekday têm descritor de reflexão.
package main

import (
	"encoding"
	"encoding/json"
	"fmt"
	"reflect"
	"time"
)

type Event struct {
	Name    string               `json:"name"`
	At      time.Time            `json:"at"`
	End     *time.Time           `json:"end,omitempty"`
	Maybe   *time.Time           `json:"maybe"`
	Zero    time.Time            `json:"zero,omitzero"`
	Timeout time.Duration        `json:"timeout"`
	Delay   time.Duration        `json:"delay,string"`
	Month   time.Month           `json:"month"`
	Day     time.Weekday         `json:"day"`
	Times   []time.Time          `json:"times"`
	ByName  map[string]time.Time `json:"by_name"`
	Any     any                  `json:"any"`
}

type stringer interface{ String() string }

func describe(t reflect.Type) {
	fmt.Println(t.String(), t.Kind(), t.Name(), t.PkgPath(), t.Size())
	if t.Kind() == reflect.Struct {
		fmt.Println(" campos:", t.NumField())
		for i := 0; i < t.NumField(); i++ {
			f := t.Field(i)
			fmt.Println("  ", f.Name, f.PkgPath, f.Type, f.IsExported(), f.Offset)
		}
	}
	marshaler := reflect.TypeOf((*json.Marshaler)(nil)).Elem()
	unmarshaler := reflect.TypeOf((*json.Unmarshaler)(nil)).Elem()
	textM := reflect.TypeOf((*encoding.TextMarshaler)(nil)).Elem()
	stringer := reflect.TypeOf((*stringer)(nil)).Elem()
	fmt.Println(" implements:", t.Implements(marshaler), t.Implements(unmarshaler), t.Implements(textM), t.Implements(stringer))
	p := reflect.PointerTo(t)
	fmt.Println(" ptr:", p, p.Implements(marshaler), p.Implements(unmarshaler))
}

func main() {
	at := time.Date(2023, time.October, 4, 10, 30, 0, 250000000, time.FixedZone("BRT", -3*3600))
	end := time.Date(2023, time.October, 4, 18, 0, 0, 0, time.UTC)
	ev := Event{
		Name:    "deploy",
		At:      at,
		End:     &end,
		Timeout: 90 * time.Second,
		Delay:   1500 * time.Millisecond,
		Month:   time.March,
		Day:     time.Friday,
		Times:   []time.Time{time.Unix(0, 0).UTC(), at.UTC()},
		ByName:  map[string]time.Time{"b": end, "a": at},
		Any:     end,
	}
	b, err := json.Marshal(ev)
	fmt.Println(string(b), err)
	b, err = json.MarshalIndent(map[string]any{"t": at, "d": time.Minute}, "", "  ")
	fmt.Println(string(b), err)

	var back Event
	err = json.Unmarshal(b, &back)
	fmt.Println(err)
	err = json.Unmarshal([]byte(`{"name":"x","at":"2024-02-29T12:00:00.5+05:30","end":"2024-03-01T00:00:00Z","maybe":null,"timeout":2000000000,"delay":"7","month":12,"day":6,"times":["2000-01-01T00:00:00Z"],"by_name":{"k":"1999-12-31T23:59:59-01:00"}}`), &back)
	fmt.Println(err)
	fmt.Println(back.Name, back.At, back.End, back.Maybe == nil, back.Timeout, back.Delay, back.Month, back.Day, back.Times, back.ByName["k"])
	fmt.Println(back.At.Equal(time.Date(2024, 2, 29, 6, 30, 0, 500000000, time.UTC)))

	// Erros: string inválida, tipo errado, ano fora do intervalo.
	var e2 Event
	fmt.Println(json.Unmarshal([]byte(`{"at":"ontem"}`), &e2))
	fmt.Println(json.Unmarshal([]byte(`{"at":12}`), &e2))
	fmt.Println(json.Unmarshal([]byte(`{"timeout":"1s"}`), &e2))
	_, err = json.Marshal(Event{At: time.Date(10000, 1, 1, 0, 0, 0, 0, time.UTC)})
	fmt.Println(err)

	var tt time.Time
	fmt.Println(json.Unmarshal([]byte(`"2001-02-03T04:05:06Z"`), &tt), tt)
	tp := new(time.Time)
	fmt.Println(json.Unmarshal([]byte(`"2001-02-03T04:05:06.7-02:00"`), tp), tp)
	var tpp *time.Time
	fmt.Println(json.Unmarshal([]byte(`"2001-02-03T04:05:06Z"`), &tpp), tpp)
	var d time.Duration
	fmt.Println(json.Unmarshal([]byte(`3600000000000`), &d), d)

	// Chave de map time.Time: vai pelo TextMarshaler/TextUnmarshaler.
	km, err := json.Marshal(map[time.Time]int{end: 1, at: 2})
	fmt.Println(string(km), err)
	var kb map[time.Time]int
	fmt.Println(json.Unmarshal(km, &kb), len(kb), kb[end])

	// reflect.
	describe(reflect.TypeOf(at))
	describe(reflect.TypeOf(time.Second))
	describe(reflect.TypeOf(time.March))
	describe(reflect.TypeOf(time.Friday))
	describe(reflect.TypeOf(&at))
	v := reflect.ValueOf(ev)
	fmt.Println(v.Field(1).Type(), v.Field(2).Type(), v.Field(5).Int(), v.Field(7).Int())
	fmt.Println(v.FieldByName("At").Interface().(time.Time).Format(time.Kitchen))
	fmt.Println(reflect.DeepEqual(ev.At, at), reflect.ValueOf(time.Time{}).IsZero())
	var iface any = at
	_, isM := iface.(json.Marshaler)
	_, isS := iface.(fmt.Stringer)
	fmt.Println(isM, isS)
	fmt.Printf("%v | %s | %d\n", ev.Timeout, ev.Month, ev.Day)
}
