// Package atlas tem o mesmo nome de um campo e de um parâmetro do obj.
package atlas

type Atlas struct{ Name string }

func Build(name string) Atlas { return Atlas{Name: name} }
