open Camlboy_lib
open Uints

module Mmu = Mock_mmu
module Cpu = Cpu.Make(Mock_mmu)

let create_cpu
    ?(a = 0x00) ?(b = 0x00) ?(c = 0x00)
    ?(d = 0x00) ?(e = 0x00) ?(h = 0x00) ?(l = 0x00)
    ?(carry=false) ?(half_carry=false) ?(sub=false) ?(zero=false)
    ?(pc = 0x00) ?(sp = 0x00)
    ?(halted = false)
    ?(mmu = Mmu.create ~size:0x10)
    ?(ime = true) () =
  let registers = Registers.create () in
  Registers.write_r registers A (Uint8.of_int a);
  Registers.write_r registers B (Uint8.of_int b);
  Registers.write_r registers C (Uint8.of_int c);
  Registers.write_r registers D (Uint8.of_int d);
  Registers.write_r registers E (Uint8.of_int e);
  Registers.write_r registers H (Uint8.of_int h);
  Registers.write_r registers L (Uint8.of_int l);
  Registers.set_flags registers ~c:carry ~h:half_carry ~n:sub ~z:zero ();
  let zeros = Bytes.create 0x10 in
  Bytes.fill zeros 0 0x10 (Char.chr 0);
  Mmu.load mmu ~src:zeros ~dst_pos:Uint16.zero;
  Cpu.For_tests.create
    ~mmu
    ~registers
    ~pc:(Uint16.of_int pc)
    ~sp:(Uint16.of_int sp)
    ~halted
    ~ime

let print_execute_result t inst =
  (* We hard code 2 as the instruction length for this test.
   * The instruction length is already tested in test_instruction.ml *)
  let inst_len = Uint16.of_int 2 in
  inst
  |> Cpu.For_tests.execute t inst_len;

  Cpu.show t
  |> print_endline

let print_addr_content mmu addr =
  Mmu.read_byte mmu (Uint16.of_int addr)
  |> show_uint8
  |> print_endline


let%expect_test "NOP" =
  let t = create_cpu () in

  NOP
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "LD B, 0xAB" =
  let t = create_cpu () in

  LD (R B, Immediate (Uint8.of_int 0xAB))
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0xab; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "LD BC, 0xAABB" =
  let t = create_cpu () in

  LD16 (RR BC, Immediate (Uint16.of_int 0x9988))
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x99; c = 0x88; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "LD (HL), B" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~l:0x2 ~b:0xAB ~mmu () in

  LD (RR_indirect HL, R B)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0xab; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x02 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}];

  print_addr_content mmu 0x2;
  [%expect {|0xab|}]

let%expect_test "LD (HL+), B" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~l:0x2 ~b:0xAB ~mmu () in

  LD (HL_inc, R B)
  |> print_execute_result t;

  [%expect{|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0xab; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x03 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}];

  print_addr_content mmu 0x2;
  [%expect {|0xab|}]

let%expect_test "LD (HL-), B" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~l:0x2 ~b:0xAB ~mmu () in

  LD (HL_dec, R B)
  |> print_execute_result t;

  [%expect{|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0xab; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x01 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}];

  print_addr_content mmu 0x2;
  [%expect {|0xab|}]

let%expect_test "LD HL, SP+0x03" =
  let t = create_cpu ~sp:0x1234 () in

  LD16 (RR HL, SP_offset (Uint8.of_int 0x03))
  |> print_execute_result t;

  [%expect{|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x12; l = 0x37 };
      pc = 0x0002; sp = 0x1234; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "LD SP, 0xABCD" =
  let t = create_cpu () in

  LD16 (SP, Immediate (0xabcd |> Uint16.of_int))
  |> print_execute_result t;

  [%expect{|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0xabcd; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "ADD A, 0xA0 (no half-carry/carry)" =
  let t = create_cpu ~a:0x01 () in

  ADD (R A, Immediate (Uint8.of_int 0xA0))
  |> print_execute_result t;

  [%expect{|
    { Cpu.Make.registers =
      { Registers.a = 0xa1; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "ADD A, 0x0F (half-carry)" =
  let t = create_cpu ~a:0x01 () in

  ADD (R A, Immediate (Uint8.of_int 0x0F))
  |> print_execute_result t;

  [%expect{|
    { Cpu.Make.registers =
      { Registers.a = 0x10; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=1, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "ADD A, 0xFF (half-carry + carry)" =
  let t = create_cpu ~a:0x1 () in

  ADD (R A, Immediate (Uint8.of_int 0xFF))
  |> print_execute_result t;

  [%expect{|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=1, n=0, z=1); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "ADC A, 0xFF (half-carry + carry)" =
  let t = create_cpu ~a:0x1 ~carry:true () in

  ADC (R A, Immediate (Uint8.of_int 0xFE))
  |> print_execute_result t;

  [%expect{|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=1, n=0, z=1); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RLCA" =
  let t = create_cpu ~a:0b10000001 () in

  RLCA
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x03; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RLA" =
  let t = create_cpu ~a:0b00000001 ~carry:true () in

  RLA
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x03; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RLA (always unset zero flag)" =
  let t = create_cpu ~a:0b10000000 ~zero:true ~carry:false () in

  RLA
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]


let%expect_test "RRCA" =
  let t = create_cpu ~a:0b00010001 () in

  RRCA
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x88; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RRA" =
  let t = create_cpu ~a:0b00010000 ~carry:true () in

  RRA
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x88; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RRA no carry" =
  let t = create_cpu ~a:0b00010000 ~carry:false () in

  RRA
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x08; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RLC A" =
  let t = create_cpu ~a:0b10000001 () in

  RLC (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x03; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RLC A (sets zero flag)" =
  let t = create_cpu ~a:0b00000000 () in

  RLC (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=1); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RL A" =
  let t = create_cpu ~a:0b00000001 ~carry:true () in

  RL (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x03; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RL A (sets zero flag)" =
  let t = create_cpu ~a:0b10000000 () in

  RL (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=1); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RRC A" =
  let t = create_cpu ~a:0b00010001 () in

  RRC (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x88; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RRC A (sets zero flag)" =
  let t = create_cpu ~a:0b00000000 () in

  RRC (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=1); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RR A" =
  let t = create_cpu ~a:0b00010000 ~carry:true () in

  RR (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x88; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RR A no carry" =
  let t = create_cpu ~a:0b00010000 ~carry:false () in

  RR (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x08; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RR A sets zero flag" =
  let t = create_cpu ~a:0b00000001 ~carry:false () in

  RR (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=1); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "SLA" =
  let t = create_cpu ~a:0b10000001 () in

  SLA (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x02; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "SLA set zero flag" =
  let t = create_cpu ~a:0b10000000 () in

  SLA (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=1); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "SLA no carry" =
  let t = create_cpu ~a:0b00001000 () in

  SLA (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x10; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "SRA" =
  let t = create_cpu ~a:0b10000001 () in

  SRA (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0xc0; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "SRA zero flag" =
  let t = create_cpu ~a:0b00000000 () in

  SRA (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=1); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]


let%expect_test "SRL" =
  let t = create_cpu ~a:0b10000001 () in

  SRL (R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x40; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "BIT (0, A) when A = 0b00000001" =
  let t = create_cpu ~a:0b00000001 ~sub:true () in

  BIT (Uint8.of_int 0, R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x01; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=1, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "BIT (1, A) when A = 0b00100000" =
  let t = create_cpu ~a:0b00100000 ~sub:true () in

  BIT (Uint8.of_int 5, R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x20; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=1, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "SET (5, A) when A = 0b00000000" =
  let t = create_cpu ~a:0b00000000 () in

  SET (Uint8.of_int 5, R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x20; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RES (4, A) when A = 0b00010011" =
  let t = create_cpu ~a:0b00010011 () in

  RES (Uint8.of_int 4, R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x03; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RES (4, A) when A = 0b00000011" =
  let t = create_cpu ~a:0b00000011 () in

  RES (Uint8.of_int 4, R A)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x03; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "PUSH BC" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~b:0xBB ~c:0xCC ~sp:8 ~mmu () in

  PUSH BC
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0xbb; c = 0xcc; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0006; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}];

  print_addr_content mmu 0x7;
  print_addr_content mmu 0x6;
  [%expect {|
     0xbb
     0xcc|}]

let%expect_test "POP BC" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~b:0xBB ~c:0xCC ~sp:6 ~mmu () in
  Mmu.write_byte mmu ~addr:Uint16.(of_int 0x7) ~data:Uint8.(of_int 0xBB);
  Mmu.write_byte mmu ~addr:Uint16.(of_int 0x6) ~data:Uint8.(of_int 0xCC);

  POP BC
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0xbb; c = 0xcc; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0008; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "JP 0x10" =
  let t = create_cpu  () in

  JP (None, Immediate Uint16.(of_int 0x10))
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0010; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "JP 0x10" =
  let t = create_cpu  () in

  JP (None, Immediate Uint16.(of_int 0x10))
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0010; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "JP NZ, 0x10 when z=0" =
  let t = create_cpu  ~zero:false () in

  JP (NZ, Immediate Uint16.(of_int 0x10))
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0010; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "JP NZ, 0x10 when z=1" =
  let t = create_cpu  ~zero:true () in

  JP (NZ, Immediate Uint16.(of_int 0x10))
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=1); h = 0x00; l = 0x00 };
      pc = 0x0002; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "JP (HL)" =
  let t = create_cpu ~h:0xAA ~l:0xBB  () in

  JP (None, RR HL)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0xaa; l = 0xbb };
      pc = 0xaabb; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "JR 0x0e" =
  let t = create_cpu ~pc:2 () in

  JR (None, Uint8.(of_int 0x0e))
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0010; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "JR C, 0x0e when c=1" =
  let t = create_cpu ~carry:true ~pc:2 () in

  JR (C, Uint8.(of_int 0x0e))
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0010; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "JR NC, 0x0e when c=1" =
  let t = create_cpu ~carry:true ~pc:2 () in

  JR (NC, Uint8.(of_int 0x0e))
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=1, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0004; sp = 0x0000; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "CALL 0x10" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~mmu ~pc:0xBBCC ~sp:0x8 () in

  CALL (None, Uint16.(of_int 0x10))
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0010; sp = 0x0006; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}];

  print_addr_content mmu 0x7;
  print_addr_content mmu 0x6;
  [%expect {|
     0xbb
     0xce|}]

let%expect_test "RET" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~sp:6 ~mmu () in
  Mmu.write_byte mmu ~addr:Uint16.(of_int 0x7) ~data:Uint8.(of_int 0xBB);
  Mmu.write_byte mmu ~addr:Uint16.(of_int 0x6) ~data:Uint8.(of_int 0xCC);

  RET None
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0xbbcc; sp = 0x0008; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}]

let%expect_test "RST 0x08" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~pc:0xBBCC ~sp:8 ~mmu () in

  RST (Uint16.of_int 0x08)
  |> print_execute_result t;

  [%expect {|
    { Cpu.Make.registers =
      { Registers.a = 0x00; b = 0x00; c = 0x00; d = 0x00; e = 0x00;
        f = (c=0, h=0, n=0, z=0); h = 0x00; l = 0x00 };
      pc = 0x0008; sp = 0x0006; mmu = <opaque>; halted = false; ime = true;
      until_enable_ime = _; until_disable_ime = _ } |}];

  print_addr_content mmu 0x7;
  print_addr_content mmu 0x6;
  [%expect {|
     0xbb
     0xce|}]
