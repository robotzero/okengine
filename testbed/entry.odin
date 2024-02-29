package testbed

import c "engine:core"
import "core:log"
import "core:mem"
import "core:fmt"
import "engine:okmath"
import "core:os"

main :: proc() {
	c.create_game = create_game
	c.main()

	os.exit(0)
}
