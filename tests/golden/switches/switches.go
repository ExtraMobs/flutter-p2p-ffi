// Package main exercita switch com break (sai só do switch), break/continue
// rotulados, fallthrough (inclusive para o default no meio) e type switch
// com break.
package main

import "fmt"

func grade(n int) string {
	s := ""
	switch {
	case n >= 90:
		s += "A"
		fallthrough
	case n >= 80:
		s += "B"
		fallthrough
	default:
		s += "!"
	case n < 0:
		s += "neg"
	}
	return s
}

func pick(n int) string {
	switch n {
	case 1:
		return "um"
	default:
		return "outro"
	case 2, 3:
		if n == 3 {
			break
		}
		return "dois"
	}
	return "três (break)"
}

func kinds(vs []any) {
	for _, v := range vs {
		switch t := v.(type) {
		case int:
			if t < 0 {
				fmt.Println("int negativo, break")
				break
			}
			fmt.Println("int", t)
		case string:
			fmt.Println("string", t)
		}
	}
}

func main() {
	for _, n := range []int{95, 85, 50, -3} {
		fmt.Println(n, grade(n))
	}
	fmt.Println(pick(1), pick(2), pick(3), pick(9))

	count := 0
	for i := 0; i < 6; i++ {
		switch {
		case i == 1:
			continue
		case i%2 == 0:
			count += 10
			break
		}
		count++
	}
	fmt.Println("count", count)

outer:
	for i := 0; i < 5; i++ {
		switch x := i * 3; {
		case x > 7:
			fmt.Println("sai do laço em", i)
			break outer
		case x == 3:
			fmt.Println("três")
			fallthrough
		case x == 100:
			fmt.Println("caiu no seguinte")
		}
	}
	kinds([]any{1, -2, "x", 3.5})
}
