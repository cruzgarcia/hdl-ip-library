from pathlib import Path
from vunit import VUnit

VU = VUnit.from_argv()
VU.add_com()
VU.add_verification_components()
VU.add_osvvm()

ROOT = Path(__file__).parent

LIB = VU.add_library("lib")
LIB.add_source_files(ROOT / "../hdl/*.vhd")
LIB.add_source_files(ROOT / "../sim/*.vhd")
LIB.entity("tb_pwm_top").scan_tests_from_file(ROOT / "../sim/tb_pwm_top.vhd")

VU.main()