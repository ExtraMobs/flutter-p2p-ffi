package cmds

type Request struct{ Path string }

type Function func(req *Request, out []string) error

type Command struct {
	Helptext string
	Run      Function
	PreRun   func(req *Request) error
}

func (c *Command) Call(path string) ([]string, error) {
	req := &Request{Path: path}
	if c.PreRun != nil {
		if err := c.PreRun(req); err != nil {
			return nil, err
		}
	}
	out := make([]string, 1)
	return out, c.Run(req, out)
}

type EncoderFunc func(req *Request) func(w []string) int

type EncoderMap map[string]EncoderFunc

func MakeTypedEncoder(tag string) func(*Request) func([]string) int {
	return func(r *Request) func([]string) int {
		return func(w []string) int { return len(w) + len(tag) + len(r.Path) }
	}
}
