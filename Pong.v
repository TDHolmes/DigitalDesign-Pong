`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////// Company: University of St. Thomas
// Engineers: Broderick Carlin and Tyler Holmes 
// 
// Create Date: 15:05:27 12/02/2013 
// Design Name: 
// Module Name: mainClock 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
// This module assumes a 640x480 monitor with 8-bit color
//////////////////////////////////////////////////////////////////////////////////

module mainClock(
    output reg Vsync, //VS out to display
    output reg Hsync, //HS out to display
    output reg [2:0] Rcolor, //Red 3-bit color to display
    output reg [2:0] Gcolor, //Green 3-bit color to display
    output reg [1:0] Bcolor, //Blue 2-bit color to display
    output reg [3:0] lScore, //left players score, 4-bit
    output reg [3:0] rScore, //right players score, 4-bit
    output reg [1:0] winner, //0 is high if right wins, 1 high for left
    output reg speakerOut, //output to the speaker
    input FPGAclk, //input clock from FPGA
    input reset, //input to reset the circuit
    input startGame, //input to start game
    input setColor, //input to set the colors based on switches
    input setSpeed, //input to set speed based on switches
    input [2:0] Rinput, //Red input from switches
    input [2:0] Ginput, //Green input from switches
    input [1:0] Binput, //Blue input from switches
    input encoderLA, //Left encoder A value
    input encoderLB, //Left encoder B value
    input encoderRA, //Right encoder A value
    input encoderRB //Right encoder B value
    );

    //All the registers used throughout the program
    
    //vga vars

    reg display;
    reg clockCount;
    reg [10:0] Hcount;
    reg [18:0] Vcount;
    reg [9:0] VpixelCount;
    reg [9:0] HpixelCount;
     
    /////////////pong vars////////////////
    //left paddle

    reg [10:0] LpaddleTLH;
    reg [10:0] LpaddleHeight;
    reg [18:0] LpaddleTLV;
    reg [18:0] LpaddleWidth;
    
    //right paddle
    reg [10:0] RpaddleTLH;
    reg [10:0] RpaddleHeight;
    reg [18:0] RpaddleTLV;
    reg [18:0] RpaddleWidth;
    
    //pong ball
    reg [10:0] ballTLH;
    reg [10:0] ballHeight;
    reg [18:0] ballTLV;
    reg [18:0] ballWidth;
    reg [3:0] ballVspeed;
    reg [3:0] ballHspeed;
    reg ballMovingRight;
    reg ballMovingDown;
    reg [4:0] ballOffset; //used for the bottom of the screen
    
    //general variables
    reg [7:0] gameSpeed;
    reg [7:0] gameCount;
    reg [2:0] Rmem;
    reg [2:0] Gmem;
    reg [1:0] Bmem;
    reg [11:0] screenWidth;
    reg [11:0] screenHeight;
    reg [1:0] gameState;
    reg [26:0] pauseCount;
    reg prevRA;
    reg prevLA;
    reg playTone;
    reg [16:0] toneFrq;
    
    parameter toneFrqMax=62000; //paramater that dictates 'beep' frequency
    parameter toneLength=12400000; //parameter that dictates the length of the 'beep'
    
    always@(posedge FPGAclk or posedge reset)
    begin
        if(reset) begin
            // reset all values to default values
            Vcount = 0;
            Hcount = 0;
            Vsync = 1;
            Hsync = 1;
            display = 0;
            VpixelCount = 0;
            HpixelCount = 0;
            clockCount = 0;
            
            ballOffset = 25;
            
            //(0,0,0) is black
            //(7,7,3) is white

            Rcolor = 0;
            Rmem = 0;
            Gcolor = 0;
            Gmem = 0;
            Bcolor = 0;
            Bmem = 0;
            
            ////////////////////////////////////////////////
            //////////////////////////GAME LOGIC////////////
            ////////////////////////////////////////////////
            
            LpaddleWidth = 20;
            LpaddleHeight = 100;
            LpaddleTLH = 20;
            LpaddleTLV = 190;
            
            RpaddleWidth = 20;
            RpaddleHeight = 100;
            RpaddleTLH = 600;
            RpaddleTLV = 190;
            
            ballTLH = 310;
            ballHeight = 20;
            ballTLV = 230;
            ballWidth = 20;
            
            playTone = 1;
            
            ballVspeed = 50;
            ballHspeed = 50;
            ballMovingRight = 0;
            ballMovingDown = 0;
            gameState = 0;
            gameSpeed = 128;
            gameCount = 0;
            screenWidth = 639;
            screenHeight = 479;
            lScore = 0;
            rScore = 0;
            pauseCount = 0;
            prevRA = 0;
            prevLA = 0;
            speakerOut = 0;
            
        end else begin

            // determines if the speaker should currenty be playing a tone
            if(playTone == 1) begin
                // less than the longest length of a 'beep'
                if(pauseCount < toneLength) begin
                    // form the frequency of the 'beep'
                    if(toneFrq == toneFrqMax) begin
                        speakerOut = ~speakerOut;
                        toneFrq = 0;
                    end else begin
                        toneFrq = toneFrq + 1;
                    end
                    pauseCount = pauseCount + 1;  // keeps track of 'beep' length
                end else begin
                    pauseCount = 0;
                    playTone = 0;
                end
            end
            
            //if right encoder A value is a rising edge
            if(prevRA != encoderRA) begin
                //determine if it should move the paddle
                if(gameState != 0 && prevRA == 0) begin
                    if(encoderRB == 1) begin
                        //counter clockwise
                        if(RpaddleTLV > (16 - gameSpeed/16)) begin
                            RpaddleTLV = RpaddleTLV - (16 - gameSpeed/16) - 1;
                        end
                    end else begin
                        //clockwise
                        if(RpaddleTLV + RpaddleHeight < screenHeight - ballOffset - (16 - gameSpeed/16)) begin
                            RpaddleTLV = RpaddleTLV + (16 - gameSpeed/16) + 1;
                        end
                    end
                end
                prevRA = encoderRA;
            end
            
            //if lft encoder A value is a rising edge
            if(prevLA != encoderLA) begin
                // determine if it should move the paddle
                if(gameState != 0 && prevLA == 0) begin
                    if(encoderLB == 1) begin
                        // counter clockwise
                        if(LpaddleTLV > (16 - gameSpeed/16)) begin
                            LpaddleTLV = LpaddleTLV - (16-gameSpeed/16) - 1;
                        end
                    end else begin
                        // clockwise
                        if(LpaddleTLV + LpaddleHeight < screenHeight - ballOffset - (16-gameSpeed/16)) begin
                            LpaddleTLV = LpaddleTLV + (16 - gameSpeed/16) + 1;
                        end
                    end
                end
                prevLA = encoderLA;
            end
            
            // divides the 50MHz clock down to 25MHz clock for VGA
            if(clockCount == 0) begin
                /////////////////Keep track of current pixels coordinate//////
                if(display == 1) begin
                ////////////////////////////////////////////////
                /////////////////////GAME LOGIC/////////////////
                ////////////////////////////////////////////////
                
                //set the background color
                if(setColor == 1) begin
                    Rmem=Rinput;
                    Gmem=Ginput;
                    Bmem=Binput;
                end
                
                //set the game speed
                if(setSpeed == 1) begin
                    gameSpeed[7:5] = Rinput;
                    gameSpeed[4:2] = Ginput;
                    gameSpeed[1:0] = Binput;
                end
                
                
                ////////////////////////DRAW LOGIC/////////////
                
                // IF statement to determin the color of the current pixel beging displayed
                if (((HpixelCount > RpaddleTLH
                        && HpixelCount < (RpaddleTLH+RpaddleWidth)
                        && (((VpixelCount-15) > RpaddleTLV))
                        && (VpixelCount-15) < (RpaddleTLV+RpaddleHeight)))
                        || (((HpixelCount > LpaddleTLH)
                        && (HpixelCount < (LpaddleTLH+LpaddleWidth))))
                        && (((VpixelCount-15) > LpaddleTLV)
                        && ((VpixelCount-15) < (LpaddleTLV+LpaddleHeight)))
                        || (((HpixelCount > ballTLH)
                        && (HpixelCount < (ballTLH+ballWidth))))
                        && (((VpixelCount-15) > ballTLV)
                        && ((VpixelCount-15) < (ballTLV+ballHeight)))) begin
                    // if it is in one of the objects, invert the backgroud color
                    Rcolor = ~Rmem;
                    Gcolor = ~Gmem;
                    Bcolor = ~Bmem;
                end else begin
                    // if it is not in one of th objects isplay the background color
                    Rcolor = Rmem;
                    Gcolor = Gmem;
                    Bcolor = Bmem;
                end
                
                
                ///////////////////////////////Move LOGIC/////////////////////////
                case(gameState)
                    0: // game not started
                    begin // if game is not started and start is pressed, start the game
                        if(startGame == 1) begin
                            gameState = 1;
                        end
                    end
                
                    1: // game started
                    begin
                        if(HpixelCount == 0 && VpixelCount == 0) begin
                            if(gameCount == gameSpeed || gameCount > gameSpeed) begin
                                gameCount=0;
                                /////////////////////////////////////////////////
                                ///////////ALL game movements here///////////////
                                /////////////////////////////////////////////////
                                
                                //////////////////ball movement//////////////////
                                if(ballMovingRight==1) begin
                                    if((ballTLH + ballWidth) > screenWidth) begin
                                        // ball hit right wall
                                        if(lScore == 9) begin
                                            gameState = 3;
                                            winner = 1;
                                            pauseCount = 0;
                                            //left player has won
                                        end else begin
                                            lScore = lScore + 1;
                                            gameState = 2;
                                            winner = 0;
                                            //no winner, increment score
                                        end

                                        // invert ball direction and allign with wall
                                        ballMovingRight = 0;
                                        ballTLH = (screenWidth - ballWidth);
                                        ballTLH = 310;
                                        ballTLV = 230;
                                    end
                                    
                                    else if((ballTLH+ballWidth)>RpaddleTLH
                                            && (ballTLH+ballWidth)<(RpaddleTLH+RpaddleWidth)
                                            && ballTLV<(RpaddleTLV+RpaddleHeight)
                                            && (ballTLV+ballHeight)>RpaddleTLV) begin
                                        // ball hit right paddle
                                        ballMovingRight = 0;
                                        playTone = 1;
                                    end else begin
                                        //no collision, move ball along
                                        ballTLH = (ballTLH + ballHspeed);
                                    end
                                end else begin
                                    if(ballTLH < ballHspeed) begin
                                        //ball hit left wall
                                        //playTone = 0;
                                        if(rScore == 9)  begin
                                            // right player has won
                                            gameState = 3;
                                            pauseCount = 0;
                                            winner = 2;
                                        end else begin
                                            rScore = rScore + 1;
                                            gameState = 2;
                                            winner = 0;
                                        end
                                        ballMovingRight = 1;
                                        ballTLH = 310;
                                        ballTLV = 230;
                                    end else if(ballTLH < (LpaddleTLH + LpaddleWidth)
                                                && ballTLH>LpaddleTLH
                                                && ballTLV<(LpaddleTLV+LpaddleHeight)
                                                && (ballTLV+ballHeight)>LpaddleTLV) begin
                                        // ball hit left paddle
                                        ballMovingRight = 1;
                                        playTone = 1;
                                    end else begin
                                        // no collision, move ball along
                                        ballTLH = (ballTLH - ballHspeed);
                                    end
                                end
                                
                                if(ballMovingDown == 1) begin
                                    // if ball is moving downwards
                                    if((ballTLV + ballHeight + ballOffset) > screenHeight) begin
                                        // added offset
                                        // ball hit bottom of screen
                                        ballMovingDown=0;
                                        ballTLV = (screenHeight - ballHeight - ballOffset);
                                    end else begin
                                        // keep moving ball along
                                        ballTLV = (ballTLV + ballVspeed);
                                    end
                                end else begin
                                    if(ballTLV < ballVspeed) begin
                                        // if ball hits top wall
                                        ballMovingDown = 1;
                                        ballTLV = 0;
                                    end else begin
                                        // move ball along
                                        ballTLV = (ballTLV - ballVspeed);
                                    end
                                end
                            end else begin
                                gameCount = gameCount + 1;
                            end
                        end
                    end
                                
                    2: // ball hit a side
                    begin
                        if(pauseCount == 33554431) begin
                            pauseCount = 0;
                            gameState = 1;
                        end else begin
                            pauseCount = pauseCount + 1;
                        end
                    end
                    
                    3: // someone has won
                    begin
                        if(startGame == 1) begin
                            rScore = 0;
                            lScore = 0;
                            gameState = 1;
                            winner = 0;
                        end else begin
                            case(winner)
                                0:
                                begin
                                    //THIS SHOULD NEVER HAPPEN
                                    winner=3;
                                end
                    
                                1:
                                begin
                                    // flash left score
                                    if(pauseCount < 1250000) begin
                                        lScore = 9;
                                    end else begin
                                        lScore = 15;
                                    end
                                end
                    
                                2:
                                begin
                                    // flash right score
                                    if(pauseCount < 1250000) begin
                                        rScore = 9;
                                    end else begin
                                        rScore = 15;
                                    end
                                end
                    
                                3:
                                begin
                                    //THIS SHOULD NEVER HAPPEN
                                end
                            endcase
                    
                            if(pauseCount > 2500000) begin
                                pauseCount = 0;
                            end else begin
                                pauseCount = pauseCount + 1;
                            end
                        end
                    end
                endcase
                
                // everything from here on out is the magical, sensative, and somehow workin VGA logic
                if(HpixelCount == 639) begin
                    HpixelCount = 0;
                    if(VpixelCount == 479) begin
                        VpixelCount = 0;
                    end else begin
                        VpixelCount = VpixelCount + 1;
                    end
                end else begin
                    HpixelCount = HpixelCount + 1;
                end
            end else begin
                Rcolor = 0;
                Gcolor = 0;
                Bcolor = 0;
            end
            
                
                ////////////////set pulse width for Hsync and set if able to display//////////////////
                if(Hcount==0) begin
                    //send HS pulse
                    Hsync = 0;
                end else if(Hcount==95) begin
                    Hsync=1;
                end
                
                else if(Hcount==143) begin
                    //store in a reg if the display is currently accepting pixel data
                    display = 1;
                    HpixelCount = 0;
                end else if(Hcount == 783) begin
                    display = 0;
                end
                Hcount = Hcount + 1;
                if(Hcount == 800) begin
                    //reset count if at right of screen
                    Hcount = 0;
                end
                
                ////////////////set pulse width for Vsync and set if able to display//////////////////
                if(Vcount == 0) begin
                    //send VS pulse
                    Vsync = 0;
                end else if(Vcount==1600) begin
                    Vsync = 1;
                    VpixelCount = 0;
                end
                Vcount = Vcount + 1;
                if(Vcount == 416800) begin
                    Vcount = 0;
                end
                clockCount = ~clockCount;
            end else begin
                clockCount = ~clockCount;
            end
        end
    end
endmodule
   