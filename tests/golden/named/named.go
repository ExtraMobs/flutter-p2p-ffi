// Package main exercita tipos nomeados sobre tipos básicos: métodos,
// operadores que preservam o tipo nomeado, conversões e identidade distinta
// de int/int64/tipo base em type switch.
package main

import "fmt"

type Celsius float64
type Fahrenheit float64
type ID int32
type Name string

func (c Celsius) ToF() Fahrenheit { return Fahrenheit(c*9/5 + 32) }

func (c Celsius) String() string { return fmt.Sprint(float64(c), "°C") }

func (id ID) Next() ID { return id + 1 }

func (n Name) Greeting() string { return "olá, " + string(n) }

const Boiling Celsius = 100

func kind(v any) string {
	switch v.(type) {
	case int:
		return "int"
	case int64:
		return "int64"
	case ID:
		return "ID"
	case int32:
		return "int32"
	case Celsius:
		return "Celsius"
	case float64:
		return "float64"
	case Name:
		return "Name"
	case string:
		return "string"
	}
	return "outro"
}

func main() {
	c := Celsius(37.5)
	fmt.Println(c, c.ToF(), Boiling.ToF(), float64(c)+0.5)
	var id ID = 2147483647
	id = id.Next() // overflow de int32
	fmt.Println(id, id.Next(), id < 0, ID(7)/2, ID(-7)%3)
	n := Name("mundo")
	fmt.Println(n.Greeting(), len(n), n+"!", n[1:3], n < "zz")
	fmt.Println(kind(1), kind(int64(1)), kind(ID(1)), kind(int32(1)), kind(c), kind(1.5), kind(n), kind("s"), kind(uint8(1)))
	fmt.Println(c == Boiling, Celsius(100) == Boiling, c+Boiling)
}
