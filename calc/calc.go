//go:generate goyacc -dlvalf -o expr.go -p "expr" expr.y

package main

import (
	"transactions/calc/expr"

	"github.com/alexbezu/gobol/ims"
	"github.com/alexbezu/gobol/pl"
)

func main() {

	var IOPCB = pl.NUMED(pl.NumT{
		"LTERM_NAME": pl.CHAR(8),
		"RESERVED":   pl.CHAR(2).INIT("io"),
		"STATUS":     pl.CHAR(2),
		"DATE_TIME":  pl.CHAR(8),
		"MSG_SEQ":    pl.FIXED_BIN(31),
		"MOD_NAME":   pl.CHAR(8).INIT("CALC"),
	})

	var INOUT_MSG_AREA = pl.CHAR(164).INIT("")
	var SCREEN_DATA = pl.NUMED(pl.NumT{
		"LL":          pl.FIXED_BIN(15),
		"ZZ":          pl.FIXED_BIN(15),
		"TRANSACTION": pl.CHAR(8),
		"PF_KEY":      pl.CHAR(5),
		"CURSOR":      pl.CHAR(4),
		"FORMULA":     pl.CHAR(36),
		"RESULT":      pl.CHAR(28),
		"SYSMSG":      pl.CHAR(79),
	}).BASED(INOUT_MSG_AREA)

	var PCB01buf = pl.CHAR(255).BASED(IOPCB)

	IOPCB.I["MOD_NAME"].Set("CALC    ")
	IOPCB.I["RESERVED"].Set("io")

	ims.DLI("GU  ", PCB01buf, INOUT_MSG_AREA)

	for IOPCB.I["STATUS"].String() == "  " {
		line := SCREEN_DATA.I["FORMULA"].String()
		res, err := expr.Calc(line)
		if err == nil {
			SCREEN_DATA.I["RESULT"].Set(res)
			SCREEN_DATA.I["SYSMSG"].Set("Your value has been calculated")
		} else {
			SCREEN_DATA.I["SYSMSG"].Set(err.Error())
		}

		ims.DLI("ISRT", PCB01buf, SCREEN_DATA)
		ims.DLI("GN  ", PCB01buf, SCREEN_DATA)
	}
}
