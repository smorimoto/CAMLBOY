open Camlboy_lib

let run_test_rom_and_print_framebuffer file =
  let rom_bytes = Read_rom_file.f file  in
  let camlboy = Camlboy.create_with_rom ~rom_bytes ~echo_flag:false in
  let rec loop () =
    let run_result = Camlboy.run_instruction camlboy in
    let prev_instr = Camlboy.For_tests.prev_inst camlboy in
    match prev_instr, run_result with
    | HALT, Frame_ended famebuffer ->
      Printf.printf "%s\n" @@ Camlboy.show camlboy;
      famebuffer
      |> Array.iteri (fun i row ->
          if row |> Array.for_all (fun color -> color = `White) then
            ()
          else begin
            let show_color = function
              | `Black -> '#'
              | `Dark_gray -> '@'
              | `Light_gray -> 'x'
              | `White -> '-'
            in
            Printf.printf "%d:" i;
            row |> Array.iter (fun color -> show_color color |> print_char);
            print_newline ()
          end
        )
    | _, _ -> loop ()
  in
  loop ()

let%expect_test "hello.gb" =
  run_test_rom_and_print_framebuffer "../../resource/test_roms/hello.gb";

  [%expect {|
    A:$29 F:ZN-- BC:$0000 DE:$9934 HL:$0A32 SP:$FFFF PC:$09F8
    48:------------------------##--##-----------###-----###--------------------------------------------##---##------------------###-------###---####-------------------
    49:------------------------##--##------------##------##--------------------------------------------##---##-------------------##--------##--##--##------------------
    50:------------------------##--##---####-----##------##-----####-----------------------------------##---##--####---##-###----##--------##------##------------------
    51:------------------------######--##--##----##------##----##--##----------------------------------##-#-##-##--##---###-##---##-----#####-----##-------------------
    52:------------------------##--##--######----##------##----##--##----------------------------------#######-##--##---##--##---##----##--##----##--------------------
    53:------------------------##--##--##--------##------##----##--##----##------##------##------------###-###-##--##---##-------##----##--##--------------------------
    54:------------------------##--##---####----####----####----####-----##------##------##------------##---##--####---####-----####----###-##---##--------------------
    64:---##----###-----------------------------------------------#---------------------------------------------####------------##-------##-----#####---#####----------
    65:--##------##----------------------------------------------##--------------------------------------------##--##------------##-----###----##---##-##---##---------
    66:-##-------##-----####---#####----###-##--####----#####---#####-----------####---##--##---####---##-###------##-------------##-----##----##--###-##--###---------
    67:-##-------##----##--##--##--##--##--##--##--##--##--------##------------##--##--##--##--##--##---###-##----##---------------##----##----##-####-##-####---------
    68:-##-------##----##--##--##--##--##--##--######---####-----##------------######--##--##--######---##--##---##---------------##-----##----####-##-####-##---------
    69:--##------##----##--##--##--##---#####--##----------##----##-#----------##-------####---##-------##-----------------------##------##----###--##-###--##---------
    70:---##----####----####---##--##------##---####---#####------##------------####-----##-----####---####------##-------------##-----######---#####---#####----------
    71:--------------------------------#####---------------------------------------------------------------------------------------------------------------------------
    72:-###------##---------------------------------------#-----------------------###---------------------------###---------------------------------------------##-----
    73:--##----------------------------------------------##------------------------##----------------------------##----------------------------------------------##----
    74:--##-----###----#####----####----#####-----------#####---####---------------##---####---######--######----##-----####-----------##--##---####---##--##-----##---
    75:--##------##----##--##--##--##--##----------------##----##--##-----------#####------##--#--##---#--##-----##----##--##----------##--##--##--##--##--##-----##---
    76:--##------##----##--##--######---####-------------##----##--##----------##--##---#####----##------##------##----######----------##--##--##--##--##--##-----##---
    77:--##------##----##--##--##----------##------------##-#--##--##----------##--##--##--##---##--#---##--#----##----##---------------#####--##--##--##--##----##----
    78:-####----####---##--##---####---#####--------------##----####------------###-##--###-##-######--######---####----####---------------##---####----###-##--##-----
    79:--------------------------------------------------------------------------------------------------------------------------------#####--------------------------- |}]
