/*
*
*  
*
*  Experimental FPGA-accelerated WPA-PSK Key Cracker for DE10-Nano 
*
*
*
*/

/*
 *  802.11 WEP / WPA-PSK Key Cracker
 *
 *  Copyright (C) 2006-2016 Thomas d'Otreppe <tdotreppe@aircrack-ng.org>
 *  Copyright (C) 2004, 2005 Christophe Devine
 *
 *  Advanced WEP attacks developed by KoreK
 *  WPA-PSK  attack code developed by Joshua Wright
 *  SHA1 MMX assembly code written by Simon Marechal
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 *
 *  In addition, as a special exception, the copyright holders give
 *  permission to link the code of portions of this program with the
 *  OpenSSL library under certain conditions as described in each
 *  individual source file, and distribute linked combinations
 *  including the two.
 *  You must obey the GNU General Public License in all respects
 *  for all of the code used other than OpenSSL. *  If you modify
 *  file(s) with this exception, you may extend this exception to your
 *  version of the file(s), but you are not obligated to do so. *  If you
 *  do not wish to do so, delete this exception statement from your
 *  version. *  If you delete this exception statement from all source
 *  files in the program, then also delete it here.
 */




#include <sys/types.h>
#include <sys/stat.h>
#include <signal.h>
#include <string.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <time.h>
#include <ctype.h>
#include <math.h>
#include <limits.h>
#include <arpa/inet.h>
#include <inttypes.h>

#include <fcntl.h>
#include <sys/mman.h>
//#include "gcrypt.h"
//#include "sha1-git.h"
//#include "gcrypt-openssl-wrapper.h"
#include <omp.h>

#include <vector>
#include <string>
#include <algorithm>
#include <chrono>

char *buf_in, *buf_out, *buf_cfg;

#define nInst 4

#define WORK_BUFFER_IN  0x20000000
#define WORK_SIZE_IN (nInst*120*60*1000)
#define WORK_BUFFER_OUT 0x28000000
#define WORK_SIZE_OUT (nInst*120*20*1000)
#define CONFIG_MEM 0xC0000000
#define WORK_SIZE_CFG (1024+32)

int rdptr(unsigned char* p)
{
	return p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24);
}


// commands
#define LCD_CLEARDISPLAY 0x01
#define LCD_RETURNHOME 0x02
#define LCD_ENTRYMODESET 0x04
#define LCD_DISPLAYCONTROL 0x08
#define LCD_CURSORSHIFT 0x10
#define LCD_FUNCTIONSET 0x20
#define LCD_SETCGRAMADDR 0x40
#define LCD_SETDDRAMADDR 0x80

// flags for display entry mode
#define LCD_ENTRYRIGHT 0x00
#define LCD_ENTRYLEFT 0x02
#define LCD_ENTRYSHIFTINCREMENT 0x01
#define LCD_ENTRYSHIFTDECREMENT 0x00

// flags for display on/off control
#define LCD_DISPLAYON 0x04
#define LCD_DISPLAYOFF 0x00
#define LCD_CURSORON 0x02
#define LCD_CURSOROFF 0x00
#define LCD_BLINKON 0x01
#define LCD_BLINKOFF 0x00

// flags for display/cursor shift
#define LCD_DISPLAYMOVE 0x08
#define LCD_CURSORMOVE 0x00
#define LCD_MOVERIGHT 0x04
#define LCD_MOVELEFT 0x00

// flags for function set
#define LCD_8BITMODE 0x10
#define LCD_4BITMODE 0x00
#define LCD_2LINE 0x08
#define LCD_1LINE 0x00
#define LCD_5x10DOTS 0x04
#define LCD_5x8DOTS 0x00

class LiquidCrystal
{
public:
	LiquidCrystal(uint8_t rs, uint8_t enable,
		uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3,
		uint8_t d4, uint8_t d5, uint8_t d6, uint8_t d7);
	LiquidCrystal(uint8_t rs, uint8_t rw, uint8_t enable,
		uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3,
		uint8_t d4, uint8_t d5, uint8_t d6, uint8_t d7);
	LiquidCrystal(uint8_t rs, uint8_t rw, uint8_t enable,
		uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3);
	LiquidCrystal(uint8_t rs, uint8_t enable,
		uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3);

	void init(uint8_t fourbitmode, uint8_t rs, uint8_t rw, uint8_t enable,
		uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3,
		uint8_t d4, uint8_t d5, uint8_t d6, uint8_t d7);

	void begin(uint8_t cols, uint8_t rows, uint8_t charsize = LCD_5x8DOTS);

	void clear();
	void home();

	void noDisplay();
	void display();
	void noBlink();
	void blink();
	void noCursor();
	void cursor();
	void scrollDisplayLeft();
	void scrollDisplayRight();
	void leftToRight();
	void rightToLeft();
	void autoscroll();
	void noAutoscroll();

	void setRowOffsets(int row1, int row2, int row3, int row4);
	void createChar(uint8_t, uint8_t[]);
	void setCursor(uint8_t, uint8_t);
	virtual size_t write(uint8_t);
	void command(uint8_t);

	void print(const char* str)
	{
		while (*str != 0)
		{
			write(*str);
			str++;
		}
	}

	//	using Print::write;
private:
	void send(uint8_t, uint8_t);
	void write4bits(uint8_t);
	void write8bits(uint8_t);
	void pulseEnable();

	uint8_t _rs_pin; // LOW: command.  HIGH: character.
	uint8_t _rw_pin; // LOW: write to LCD.  HIGH: read from LCD.
	uint8_t _enable_pin; // activated by a HIGH pulse.
	uint8_t _data_pins[8];

	uint8_t _displayfunction;
	uint8_t _displaycontrol;
	uint8_t _displaymode;

	uint8_t _initialized;

	uint8_t _numlines;
	uint8_t _row_offsets[4];
};



#include <stdio.h>
#include <string.h>
#include <inttypes.h>

int g_pin_value = 0;
void digitalWrite(int pin, int value)
{

	if (value)
		g_pin_value |= (1 << pin);
	else
		g_pin_value &= ~(1 << pin);
	*(int*)(buf_cfg + 0x400) = g_pin_value;

	/*
	if (value)
	*(int*)(buf_cfg + 0x414) = pin;
	else
	*(int*)(buf_cfg + 0x410) = pin;
	*/
}

void pinMode(int pin, int value)
{
}

#define LOW 0
#define HIGH 1
#define OUTPUT 0
// When the display powers up, it is configured as follows:
//
// 1. Display clear
// 2. Function set: 
//    DL = 1; 8-bit interface data 
//    N = 0; 1-line display 
//    F = 0; 5x8 dot character font 
// 3. Display on/off control: 
//    D = 0; Display off 
//    C = 0; Cursor off 
//    B = 0; Blinking off 
// 4. Entry mode set: 
//    I/D = 1; Increment by 1 
//    S = 0; No shift 
//
// Note, however, that resetting the Arduino doesn't reset the LCD, so we
// can't assume that its in that state when a sketch starts (and the
// LiquidCrystal constructor is called).

LiquidCrystal::LiquidCrystal(uint8_t rs, uint8_t rw, uint8_t enable,
	uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3,
	uint8_t d4, uint8_t d5, uint8_t d6, uint8_t d7)
{
	init(0, rs, rw, enable, d0, d1, d2, d3, d4, d5, d6, d7);
}

LiquidCrystal::LiquidCrystal(uint8_t rs, uint8_t enable,
	uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3,
	uint8_t d4, uint8_t d5, uint8_t d6, uint8_t d7)
{
	init(0, rs, 255, enable, d0, d1, d2, d3, d4, d5, d6, d7);
}

LiquidCrystal::LiquidCrystal(uint8_t rs, uint8_t rw, uint8_t enable,
	uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3)
{
	init(1, rs, rw, enable, d0, d1, d2, d3, 0, 0, 0, 0);
}

LiquidCrystal::LiquidCrystal(uint8_t rs, uint8_t enable,
	uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3)
{
	init(1, rs, 255, enable, d0, d1, d2, d3, 0, 0, 0, 0);
}

void LiquidCrystal::init(uint8_t fourbitmode, uint8_t rs, uint8_t rw, uint8_t enable,
	uint8_t d0, uint8_t d1, uint8_t d2, uint8_t d3,
	uint8_t d4, uint8_t d5, uint8_t d6, uint8_t d7)
{
	_rs_pin = rs;
	_rw_pin = rw;
	_enable_pin = enable;

	_data_pins[0] = d0;
	_data_pins[1] = d1;
	_data_pins[2] = d2;
	_data_pins[3] = d3;
	_data_pins[4] = d4;
	_data_pins[5] = d5;
	_data_pins[6] = d6;
	_data_pins[7] = d7;

	if (fourbitmode)
		_displayfunction = LCD_4BITMODE | LCD_1LINE | LCD_5x8DOTS;
	else
		_displayfunction = LCD_8BITMODE | LCD_1LINE | LCD_5x8DOTS;

	begin(16, 1);
}

void delayMicroseconds(int t)
{
	struct timespec ts;
	ts.tv_sec = 0;
	ts.tv_nsec = uint64_t(t) * 1000;
	nanosleep(&ts, 0);
}


void LiquidCrystal::begin(uint8_t cols, uint8_t lines, uint8_t dotsize) {
	if (lines > 1) {
		_displayfunction |= LCD_2LINE;
	}
	_numlines = lines;

	setRowOffsets(0x00, 0x40, 0x00 + cols, 0x40 + cols);

	// for some 1 line displays you can select a 10 pixel high font
	if ((dotsize != LCD_5x8DOTS) && (lines == 1)) {
		_displayfunction |= LCD_5x10DOTS;
	}

	pinMode(_rs_pin, OUTPUT);
	// we can save 1 pin by not using RW. Indicate by passing 255 instead of pin#
	if (_rw_pin != 255) {
		pinMode(_rw_pin, OUTPUT);
	}
	pinMode(_enable_pin, OUTPUT);

	// Do these once, instead of every time a character is drawn for speed reasons.
	for (int i = 0; i<((_displayfunction & LCD_8BITMODE) ? 8 : 4); ++i)
	{
		pinMode(_data_pins[i], OUTPUT);
	}

	// SEE PAGE 45/46 FOR INITIALIZATION SPECIFICATION!
	// according to datasheet, we need at least 40ms after power rises above 2.7V
	// before sending commands. Arduino can turn on way before 4.5V so we'll wait 50
	delayMicroseconds(50000);
	// Now we pull both RS and R/W low to begin commands
	digitalWrite(_rs_pin, LOW);
	digitalWrite(_enable_pin, LOW);
	if (_rw_pin != 255) {
		digitalWrite(_rw_pin, LOW);
	}

	//put the LCD into 4 bit or 8 bit mode
	if (!(_displayfunction & LCD_8BITMODE)) {
		// this is according to the hitachi HD44780 datasheet
		// figure 24, pg 46

		// we start in 8bit mode, try to set 4 bit mode
		write4bits(0x03);
		delayMicroseconds(4500); // wait min 4.1ms

		// second try
		write4bits(0x03);
		delayMicroseconds(4500); // wait min 4.1ms

		// third go!
		write4bits(0x03);
		delayMicroseconds(150);

		// finally, set to 4-bit interface
		write4bits(0x02);
	}
	else {
		// this is according to the hitachi HD44780 datasheet
		// page 45 figure 23

		// Send function set command sequence
		command(LCD_FUNCTIONSET | _displayfunction);
		delayMicroseconds(4500);  // wait more than 4.1ms

		// second try
		command(LCD_FUNCTIONSET | _displayfunction);
		delayMicroseconds(150);

		// third go
		command(LCD_FUNCTIONSET | _displayfunction);
	}

	// finally, set # lines, font size, etc.
	command(LCD_FUNCTIONSET | _displayfunction);

	// turn the display on with no cursor or blinking default
	_displaycontrol = LCD_DISPLAYON | LCD_CURSOROFF | LCD_BLINKOFF;
	display();

	// clear it off
	clear();

	// Initialize to default text direction (for romance languages)
	_displaymode = LCD_ENTRYLEFT | LCD_ENTRYSHIFTDECREMENT;
	// set the entry mode
	command(LCD_ENTRYMODESET | _displaymode);

}

void LiquidCrystal::setRowOffsets(int row0, int row1, int row2, int row3)
{
	_row_offsets[0] = row0;
	_row_offsets[1] = row1;
	_row_offsets[2] = row2;
	_row_offsets[3] = row3;
}

/********** high level commands, for the user! */
void LiquidCrystal::clear()
{
	command(LCD_CLEARDISPLAY);  // clear display, set cursor position to zero
	delayMicroseconds(2000);  // this command takes a long time!
}

void LiquidCrystal::home()
{
	command(LCD_RETURNHOME);  // set cursor position to zero
	delayMicroseconds(2000);  // this command takes a long time!
}

void LiquidCrystal::setCursor(uint8_t col, uint8_t row)
{
	const size_t max_lines = sizeof(_row_offsets) / sizeof(*_row_offsets);
	if (row >= max_lines) {
		row = max_lines - 1;    // we count rows starting w/0
	}
	if (row >= _numlines) {
		row = _numlines - 1;    // we count rows starting w/0
	}

	command(LCD_SETDDRAMADDR | (col + _row_offsets[row]));
}

// Turn the display on/off (quickly)
void LiquidCrystal::noDisplay() {
	_displaycontrol &= ~LCD_DISPLAYON;
	command(LCD_DISPLAYCONTROL | _displaycontrol);
}
void LiquidCrystal::display() {
	_displaycontrol |= LCD_DISPLAYON;
	command(LCD_DISPLAYCONTROL | _displaycontrol);
}

// Turns the underline cursor on/off
void LiquidCrystal::noCursor() {
	_displaycontrol &= ~LCD_CURSORON;
	command(LCD_DISPLAYCONTROL | _displaycontrol);
}
void LiquidCrystal::cursor() {
	_displaycontrol |= LCD_CURSORON;
	command(LCD_DISPLAYCONTROL | _displaycontrol);
}

// Turn on and off the blinking cursor
void LiquidCrystal::noBlink() {
	_displaycontrol &= ~LCD_BLINKON;
	command(LCD_DISPLAYCONTROL | _displaycontrol);
}
void LiquidCrystal::blink() {
	_displaycontrol |= LCD_BLINKON;
	command(LCD_DISPLAYCONTROL | _displaycontrol);
}

// These commands scroll the display without changing the RAM
void LiquidCrystal::scrollDisplayLeft(void) {
	command(LCD_CURSORSHIFT | LCD_DISPLAYMOVE | LCD_MOVELEFT);
}
void LiquidCrystal::scrollDisplayRight(void) {
	command(LCD_CURSORSHIFT | LCD_DISPLAYMOVE | LCD_MOVERIGHT);
}

// This is for text that flows Left to Right
void LiquidCrystal::leftToRight(void) {
	_displaymode |= LCD_ENTRYLEFT;
	command(LCD_ENTRYMODESET | _displaymode);
}

// This is for text that flows Right to Left
void LiquidCrystal::rightToLeft(void) {
	_displaymode &= ~LCD_ENTRYLEFT;
	command(LCD_ENTRYMODESET | _displaymode);
}

// This will 'right justify' text from the cursor
void LiquidCrystal::autoscroll(void) {
	_displaymode |= LCD_ENTRYSHIFTINCREMENT;
	command(LCD_ENTRYMODESET | _displaymode);
}

// This will 'left justify' text from the cursor
void LiquidCrystal::noAutoscroll(void) {
	_displaymode &= ~LCD_ENTRYSHIFTINCREMENT;
	command(LCD_ENTRYMODESET | _displaymode);
}

// Allows us to fill the first 8 CGRAM locations
// with custom characters
void LiquidCrystal::createChar(uint8_t location, uint8_t charmap[]) {
	location &= 0x7; // we only have 8 locations 0-7
	command(LCD_SETCGRAMADDR | (location << 3));
	for (int i = 0; i<8; i++) {
		write(charmap[i]);
	}
}

/*********** mid level commands, for sending data/cmds */

inline void LiquidCrystal::command(uint8_t value) {
	send(value, LOW);
}

inline size_t LiquidCrystal::write(uint8_t value) {
	send(value, HIGH);
	return 1; // assume sucess
}

/************ low level data pushing commands **********/

// write either command or data, with automatic 4/8-bit selection
void LiquidCrystal::send(uint8_t value, uint8_t mode) {
	digitalWrite(_rs_pin, mode);

	// if there is a RW pin indicated, set it low to Write
	if (_rw_pin != 255) {
		digitalWrite(_rw_pin, LOW);
	}

	if (_displayfunction & LCD_8BITMODE) {
		write8bits(value);
	}
	else {
		write4bits(value >> 4);
		write4bits(value);
	}
}

void LiquidCrystal::pulseEnable(void) {
	digitalWrite(_enable_pin, LOW);
	delayMicroseconds(1);
	digitalWrite(_enable_pin, HIGH);
	delayMicroseconds(1);    // enable pulse must be >450ns
	digitalWrite(_enable_pin, LOW);
	delayMicroseconds(100);   // commands need > 37us to settle
}

void LiquidCrystal::write4bits(uint8_t value) {
	for (int i = 0; i < 4; i++) {
		digitalWrite(_data_pins[i], (value >> i) & 0x01);
	}

	pulseEnable();
}

void LiquidCrystal::write8bits(uint8_t value) {
	for (int i = 0; i < 8; i++) {
		digitalWrite(_data_pins[i], (value >> i) & 0x01);
	}

	pulseEnable();
}



uint32_t byteswap(const unsigned char* p)
{
	return p[3] + (p[2] << 8) + (p[1] << 16) + (p[0] << 24);
}

uint32_t byteswap(uint32_t x)
{
	return (x >> 24) | ((x >> 8) & 0xFF00) | ((x << 8) & 0xFF0000) | (x << 24);
}


using namespace std;
typedef unsigned char u8;
typedef unsigned int u32;


typedef struct {
	unsigned long long size;
	unsigned int h0, h1, h2, h3, h4;
	unsigned int W[16];
} blk_SHA_CTX;

void blk_SHA1_Init(blk_SHA_CTX *ctx);
void blk_SHA1_Update(blk_SHA_CTX *ctx, const void *dataIn, unsigned long len, bool debug = false);
void blk_SHA1_Final(unsigned char hashout[20], blk_SHA_CTX *ctx, bool debug = false);


#if defined(__GNUC__) && (defined(__i386__) || defined(__x86_64__))

/*
* Force usage of rol or ror by selecting the one with the smaller constant.
* It _can_ generate slightly smaller code (a constant of 1 is special), but
* perhaps more importantly it's possibly faster on any uarch that does a
* rotate with a loop.
*/

#define SHA_ASM(op, x, n) ({ unsigned int __res; __asm__(op " %1,%0":"=r" (__res):"i" (n), "0" (x)); __res; })
#define SHA_ROL(x,n)	SHA_ASM("rol", x, n)
#define SHA_ROR(x,n)	SHA_ASM("ror", x, n)

#else

#define SHA_ROT(X,l,r)	(((X) << (l)) | ((X) >> (r)))
#define SHA_ROL(X,n)	SHA_ROT(X,n,32-(n))
#define SHA_ROR(X,n)	SHA_ROT(X,32-(n),n)

#endif

/*
* If you have 32 registers or more, the compiler can (and should)
* try to change the array[] accesses into registers. However, on
* machines with less than ~25 registers, that won't really work,
* and at least gcc will make an unholy mess of it.
*
* So to avoid that mess which just slows things down, we force
* the stores to memory to actually happen (we might be better off
* with a 'W(t)=(val);asm("":"+m" (W(t))' there instead, as
* suggested by Artur Skawina - that will also make gcc unable to
* try to do the silly "optimize away loads" part because it won't
* see what the value will be).
*
* Ben Herrenschmidt reports that on PPC, the C version comes close
* to the optimized asm with this (ie on PPC you don't want that
* 'volatile', since there are lots of registers).
*
* On ARM we get the best code generation by forcing a full memory barrier
* between each SHA_ROUND, otherwise gcc happily get wild with spilling and
* the stack frame size simply explode and performance goes down the drain.
*/

#if defined(__i386__) || defined(__x86_64__)
#define setW(x, val) (*(volatile unsigned int *)&W(x) = (val))
#elif defined(__GNUC__) && defined(__arm__)
#define setW(x, val) do { W(x) = (val); __asm__("":::"memory"); } while (0)
#else
#define setW(x, val) (W(x) = (val))
#endif

/*
* Performance might be improved if the CPU architecture is OK with
* unaligned 32-bit loads and a fast ntohl() is available.
* Otherwise fall back to byte loads and shifts which is portable,
* and is faster on architectures with memory alignment issues.
*/

#define _byteswap_ulong ntohl
#define get_be32(p)	ntohl(*(unsigned int *)(p))
#define put_be32(p, v)	do { *(unsigned int *)(p) = htonl(v); } while (0)


/* This "rolls" over the 512-bit array */
#define W(x) (array[(x)&15])

/*
* Where do we get the source from? The first 16 iterations get it from
* the input data, the next mix it from the 512-bit array.
*/
#define SHA_SRC(t) get_be32(data + t)
#define SHA_MIX(t) SHA_ROL(W(t+13) ^ W(t+8) ^ W(t+2) ^ W(t), 1)

#define SHA_ROUND(t, input, fn, constant, A, B, C, D, E) do { \
	unsigned int TEMP = input(t); setW(t, TEMP); \
	E += TEMP + SHA_ROL(A,5) + (fn) + (constant); \
	B = SHA_ROR(B, 2); } while (0)

//printf("c temp %08x, A %08x, rol %08x, F %08x\n", TEMP, A, SHA_ROL(A, 5), (fn)); 

#define T_0_15(t, A, B, C, D, E)  SHA_ROUND(t, SHA_SRC, (((C^D)&B)^D) , 0x5a827999, A, B, C, D, E )
#define T_16_19(t, A, B, C, D, E) SHA_ROUND(t, SHA_MIX, (((C^D)&B)^D) , 0x5a827999, A, B, C, D, E )
#define T_20_39(t, A, B, C, D, E) SHA_ROUND(t, SHA_MIX, (B^C^D) , 0x6ed9eba1, A, B, C, D, E )
#define T_40_59(t, A, B, C, D, E) SHA_ROUND(t, SHA_MIX, ((B&C)+(D&(B^C))) , 0x8f1bbcdc, A, B, C, D, E )
#define T_60_79(t, A, B, C, D, E) SHA_ROUND(t, SHA_MIX, (B^C^D) ,  0xca62c1d6, A, B, C, D, E )

static void blk_SHA1_Block(
	unsigned int& h0, unsigned int& h1, unsigned int& h2, unsigned int& h3, unsigned int& h4,
	const unsigned int *data)
{
	unsigned int A, B, C, D, E;
	unsigned int array[16];

	A = h0;
	B = h1;
	C = h2;
	D = h3;
	E = h4;
	//printf("* %08x %08x %08x / %08x %08x => ", A, B, C, data[0], data[1]);

	/* Round 1 - iterations 0-16 take their input from 'data' */
	//printf("c %08x %08x %08x %08x %08x\n", E, D, C, B, A);
	T_0_15(0, A, B, C, D, E);
	//printf("c %08x %08x %08x %08x %08x\n", D, C, B, A, E);
	T_0_15(1, E, A, B, C, D);
	//printf("c %08x %08x %08x %08x %08x\n", C, B, A, E, D);
	T_0_15(2, D, E, A, B, C);
	//printf("c %08x %08x %08x %08x %08x\n", B, A, E, D, C);
	T_0_15(3, C, D, E, A, B);
	//printf("c %08x %08x %08x %08x %08x\n", A, E, D, C, B);
	T_0_15(4, B, C, D, E, A);
	T_0_15(5, A, B, C, D, E);
	T_0_15(6, E, A, B, C, D);
	T_0_15(7, D, E, A, B, C);
	T_0_15(8, C, D, E, A, B);
	T_0_15(9, B, C, D, E, A);
	T_0_15(10, A, B, C, D, E);
	T_0_15(11, E, A, B, C, D);
	T_0_15(12, D, E, A, B, C);
	T_0_15(13, C, D, E, A, B);
	T_0_15(14, B, C, D, E, A);
	T_0_15(15, A, B, C, D, E);

	/* Round 1 - tail. Input from 512-bit mixing array */
	T_16_19(16, E, A, B, C, D);
	T_16_19(17, D, E, A, B, C);
	T_16_19(18, C, D, E, A, B);
	T_16_19(19, B, C, D, E, A);
	//printf("c %08x %08x %08x %08x %08x\n", A, B, C, D, E);
	//	goto done;

	/* Round 2 */
	T_20_39(20, A, B, C, D, E);
	T_20_39(21, E, A, B, C, D);
	T_20_39(22, D, E, A, B, C);
	T_20_39(23, C, D, E, A, B);
	T_20_39(24, B, C, D, E, A);
	T_20_39(25, A, B, C, D, E);
	T_20_39(26, E, A, B, C, D);
	T_20_39(27, D, E, A, B, C);
	T_20_39(28, C, D, E, A, B);
	T_20_39(29, B, C, D, E, A);
	T_20_39(30, A, B, C, D, E);
	T_20_39(31, E, A, B, C, D);
	T_20_39(32, D, E, A, B, C);
	T_20_39(33, C, D, E, A, B);
	T_20_39(34, B, C, D, E, A);
	T_20_39(35, A, B, C, D, E);
	T_20_39(36, E, A, B, C, D);
	T_20_39(37, D, E, A, B, C);
	T_20_39(38, C, D, E, A, B);
	T_20_39(39, B, C, D, E, A);

	/* Round 3 */
	T_40_59(40, A, B, C, D, E);
	T_40_59(41, E, A, B, C, D);
	T_40_59(42, D, E, A, B, C);
	T_40_59(43, C, D, E, A, B);
	T_40_59(44, B, C, D, E, A);
	T_40_59(45, A, B, C, D, E);
	T_40_59(46, E, A, B, C, D);
	T_40_59(47, D, E, A, B, C);
	T_40_59(48, C, D, E, A, B);
	T_40_59(49, B, C, D, E, A);
	T_40_59(50, A, B, C, D, E);
	T_40_59(51, E, A, B, C, D);
	T_40_59(52, D, E, A, B, C);
	T_40_59(53, C, D, E, A, B);
	T_40_59(54, B, C, D, E, A);
	T_40_59(55, A, B, C, D, E);
	T_40_59(56, E, A, B, C, D);
	T_40_59(57, D, E, A, B, C);
	T_40_59(58, C, D, E, A, B);
	T_40_59(59, B, C, D, E, A);

	/* Round 4 */
	T_60_79(60, A, B, C, D, E);
	T_60_79(61, E, A, B, C, D);
	T_60_79(62, D, E, A, B, C);
	T_60_79(63, C, D, E, A, B);
	T_60_79(64, B, C, D, E, A);
	T_60_79(65, A, B, C, D, E);
	T_60_79(66, E, A, B, C, D);
	T_60_79(67, D, E, A, B, C);
	T_60_79(68, C, D, E, A, B);
	T_60_79(69, B, C, D, E, A);
	T_60_79(70, A, B, C, D, E);
	T_60_79(71, E, A, B, C, D);
	T_60_79(72, D, E, A, B, C);
	T_60_79(73, C, D, E, A, B);
	T_60_79(74, B, C, D, E, A);
	T_60_79(75, A, B, C, D, E);
	T_60_79(76, E, A, B, C, D);
	T_60_79(77, D, E, A, B, C);
	T_60_79(78, C, D, E, A, B);
	T_60_79(79, B, C, D, E, A);
	//printf("c %08x %08x %08x %08x %08x\n", E, D, C, B, A);
done:
	h0 += A;
	h1 += B;
	h2 += C;
	h3 += D;
	h4 += E;
	//printf("* %08x %08x %08x\n", h0, h1, h2);
}

void sha1_transform(unsigned int* ctx, const unsigned int *data)
{
	int temp[16];
	for (int i = 0; i < 5; i++)
		temp[i] = _byteswap_ulong(data[i]);
	temp[5] = _byteswap_ulong(0x80000000);
	for (int i = 6; i<15; i++)
		temp[i] = 0;
	temp[15] = _byteswap_ulong(0x000002a0);
	blk_SHA1_Block(ctx[0], ctx[1], ctx[2], ctx[3], ctx[4], (const unsigned int*)temp);
}

void blk_SHA1_Block(blk_SHA_CTX *ctx, const unsigned int *data)
{
	blk_SHA1_Block(ctx->h0, ctx->h1, ctx->h2, ctx->h3, ctx->h4, data);
}

void blk_SHA1_Init(blk_SHA_CTX *ctx)
{
	ctx->size = 0;

	/* Initialize H with the magic constants (see FIPS180 for constants) */
	ctx->h0 = 0x67452301;
	ctx->h1 = 0xefcdab89;
	ctx->h2 = 0x98badcfe;
	ctx->h3 = 0x10325476;
	ctx->h4 = 0xc3d2e1f0;
}

void blk_SHA1_Update(blk_SHA_CTX *ctx, const void *data, unsigned long len, bool debug)
{
	unsigned int lenW = ctx->size & 63;

	ctx->size += len;

	/* Read the data into W and process blocks as they get full */
	if (lenW) {
		unsigned int left = 64 - lenW;
		if (len < left)
			left = len;
		memcpy(lenW + (char *)ctx->W, data, left);
		lenW = (lenW + left) & 63;
		len -= left;
		data = ((const char *)data + left);
		if (lenW)
			return;
		if (debug)
		{
			printf("%08x %08x %08x %08x %08x\n", ctx->h0, ctx->h1, ctx->h2, ctx->h3, ctx->h4);
			for (int i = 0; i < 16; i++)
				printf("%08x\n", ctx->W[i]);
			printf("=>\n");
		}
		blk_SHA1_Block(ctx, ctx->W);
		if (debug)
		{
			printf("%08x %08x %08x %08x %08x\n", ctx->h0, ctx->h1, ctx->h2, ctx->h3, ctx->h4);
		}
	}
	while (len >= 64) {
		blk_SHA1_Block(ctx, (const unsigned int*)data);
		data = ((const char *)data + 64);
		len -= 64;
	}
	if (len)
		memcpy(ctx->W, data, len);
}

void blk_SHA1_Final(unsigned char hashout[20], blk_SHA_CTX *ctx, bool debug)
{
	static const unsigned char pad[64] = { 0x80 };
	unsigned int padlen[2];
	int i;

	/* Pad with a binary 1 (ie 0x80), then zeroes, then length */
	padlen[0] = htonl((uint32_t)(ctx->size >> 29));
	padlen[1] = htonl((uint32_t)(ctx->size << 3));

	i = ctx->size & 63;
	blk_SHA1_Update(ctx, pad, 1 + (63 & (55 - i)));
	blk_SHA1_Update(ctx, padlen, 8, debug);

	/* Output hash */
	put_be32(hashout + 0 * 4, ctx->h0);
	put_be32(hashout + 1 * 4, ctx->h1);
	put_be32(hashout + 2 * 4, ctx->h2);
	put_be32(hashout + 3 * 4, ctx->h3);
	put_be32(hashout + 4 * 4, ctx->h4);
}

void SHA1_16x5(const uint32_t* ctx, const uint32_t* data, uint32_t* data_out, bool debug = false)
{
	uint32_t w[5];
	memcpy(w, ctx, 20);
	/*
	if (debug)
	{
	for (int i = 0; i < 5; i++)
	printf("%08x ", w[i]);
	for (int i = 0; i < 16; i++)
	printf("%08x ", data[i]);
	printf("\n");
	}
	*/
	blk_SHA1_Block(w[0], w[1], w[2], w[3], w[4], (const uint32_t*)data);

	/* Output hash */
	put_be32(data_out + 0, w[0]);
	put_be32(data_out + 1, w[1]);
	put_be32(data_out + 2, w[2]);
	put_be32(data_out + 3, w[3]);
	put_be32(data_out + 4, w[4]);
}

void SHA1_5x5(const uint32_t* ctx, const uint32_t* data, uint32_t* data_out, bool debug=false)
{
	uint32_t t[16];
	memcpy(t, data, 5 * 4);
	t[5] = 0x80;
	for (int i = 6; i < 15; i++)
		t[i] = 0;
	t[14] = 0;// htonl((uint32_t)(cs >> 29));
	t[15] = 0xa0020000;

	uint32_t w[5];
	memcpy(w, ctx, 20);
	/*
	if (debug)
	{
		for (int i = 0; i < 5; i++)
			printf("%08x ", w[i]);
		for (int i = 0; i < 16; i++)
			printf("%08x ", data[i]);
		printf("\n");
	}
	*/
	blk_SHA1_Block(w[0], w[1], w[2], w[3], w[4], (const uint32_t*)t);

	/* Output hash */
	memcpy(data_out, w, 20);
	/*
	put_be32(data_out + 0, w[0]);
	put_be32(data_out + 1, w[1]);
	put_be32(data_out + 2, w[2]);
	put_be32(data_out + 3, w[3]);
	put_be32(data_out + 4, w[4]);
	*/
}

void blk_SHA1_Pass(blk_SHA_CTX *ctx, unsigned int * data, bool debug=false)
{
	unsigned int temp[5];
	temp[0] = ctx->h0;
	temp[1] = ctx->h1;
	temp[2] = ctx->h2;
	temp[3] = ctx->h3;
	temp[4] = ctx->h4;

	data[5] = 0x80;
	for (int i = 6; i < 15; i++)
		data[i] = 0;
	data[14] = 0;// htonl((uint32_t)(cs >> 29));
	data[15] = 0xa0020000;

	if (debug)
	{
		for (int i = 0; i < 5; i++)
			printf("%08x ", temp[i]);
		for (int i = 0; i < 16; i++)
			printf("%08x ", data[i]);
		printf("\n");
	}

	blk_SHA1_Block(temp[0], temp[1], temp[2], temp[3], temp[4], (const unsigned int*)data);

	/* Output hash */
	put_be32(data + 0, temp[0]);
	put_be32(data + 1, temp[1]);
	put_be32(data + 2, temp[2]);
	put_be32(data + 3, temp[3]);
	put_be32(data + 4, temp[4]);
}


void blk_SHA1_Pass(const unsigned int *ctx, unsigned int * data)
{
	unsigned int temp[5];
	temp[0] = ctx[0];
	temp[1] = ctx[1];
	temp[2] = ctx[2];
	temp[3] = ctx[3];
	temp[4] = ctx[4];

	data[5] = 0x80;
	for (int i = 6; i < 15; i++)
		data[i] = 0;
	data[14] = 0;// htonl((uint32_t)(cs >> 29));
	data[15] = 0xa0020000;

	blk_SHA1_Block(temp[0], temp[1], temp[2], temp[3], temp[4], (const unsigned int*)data);

	/* Output hash */
	put_be32(data + 0, temp[0]);
	put_be32(data + 1, temp[1]);
	put_be32(data + 2, temp[2]);
	put_be32(data + 3, temp[3]);
	put_be32(data + 4, temp[4]);
}


vector<string> g_vdict;
int g_vdictpos = 0;

void readdict(const char* name)
{
	g_vdict.clear();
	FILE* f = 0;
	f=fopen(name, "r");
	if (f == 0)
	{
		string s = "c:\\texts\\wordlists\\";
		s += name;
		f=fopen(s.c_str(), "r");
	}
	if (f == 0)
	{
		printf("ERROR: failed to open %s!\n", name);
		exit(-1);
	}
	while (true)
	{
		char key[64];
		if (fgets(key, 64, f) == NULL)
			break;
		int i;
		for (i = 0; i < 64; i++)
		{
			if (key[i] == 0)
				break;
		}
		if (i < 8)
			continue;
		if (i > 64)
			i = 64;

		while (i>0 && (key[i - 1] == '\r' || key[i - 1] == '\n'))
		{
			key[i - 1] = 0;
			i--;
		}
		if (i <= 0)
			continue;

		for (int j = 0; j<i; j++)
			if (!isascii(key[j]) || key[j] < 32) i = 0;
		if (i >= 8)
			g_vdict.push_back(key);
	}
	printf("%s: read %d keys\n", name, g_vdict.size());
	fclose(f);
	g_vdictpos = 0;
}

void read_passphrases(vector<u8>& v, uint64_t nmax)
{	
	static const uint64_t base = 0;
	static const uint64_t cap = 10000000000ull;
	static uint64_t last_pos = base;
	size_t sz = min(nmax, cap - last_pos);
	v.resize(sz*64);
#pragma omp parallel for
	for(int64_t j=0; j<sz; j++)
	{
		uint64_t pos = last_pos + j;
		uint64_t x = pos;
		
		sprintf((char*)&v[j * 64], "%010lld", x);
		memset(&v[j * 64 + 10], 0, 64 - 10);
	}
	last_pos += sz;
}

#pragma pack(push, 1)
struct hccapx_t
{
	uint32_t signature;
	uint32_t version;
	uint8_t authenticated;
	uint8_t essid_len;
	uint8_t essid[32];
	uint8_t keyver;
	uint8_t keymic[16];
	uint8_t mac_ap[6];
	uint8_t nonce_ap[32];
	uint8_t mac_sta[6];
	uint8_t nonce_sta[32];
	uint16_t eapol_len;
	uint8_t eapol[256];
};

struct hccapx_v4
{
	u32 signature;
	u32 version;
	u8  message_pair;
	u8  essid_len;
	u8  essid[32];
	u8  keyver;
	u8  keymic[16];
	u8  mac_ap[6];
	u8  nonce_ap[32];
	u8  mac_sta[6];
	u8  nonce_sta[32];
	uint16_t eapol_len;
	u8  eapol[256];
};
#pragma pack(pop)

//HMAC(EVP_sha1(), (unsigned char *)key, strlen(key), (unsigned char*)essid, slen, pmk, NULL);
inline void HMAC_EVP_MD5(unsigned char* key, size_t klen, unsigned char* data, size_t dlen, unsigned char* res, size_t rlen)
{
	printf("ERROR: HMAC_EVP_MD5 not implemented!\n");
	exit(-1);
}

typedef unsigned char uchar;
void blk_SHA1_Init(blk_SHA_CTX *ctx);
void blk_SHA1_Block(blk_SHA_CTX *ctx, const unsigned int *data);


void HMAC_EVP_SHA1(const unsigned char* key, size_t klen, const unsigned char* data, size_t dlen, unsigned char* res, size_t rlen, bool debug=false)
{
	debug = false;
	uchar ctx1[64];
	uchar ctx2[64];
	int i;
	for (i = 0; i < klen; i++)
	{
		ctx1[i] = key[i] ^ 0x36;
		ctx2[i] = key[i] ^ 0x5c;
	}
	for (; i < 64; i++)
	{
		ctx1[i] = 0x36;
		ctx2[i] = 0x5c;
	}

	blk_SHA_CTX c1, c2;
	blk_SHA1_Init(&c1);
	blk_SHA1_Init(&c2);

	blk_SHA1_Block(&c1, (const unsigned int*)ctx1);
	c1.size = 64;
	blk_SHA1_Update(&c1, data, dlen);
	uchar digest[64];
	blk_SHA1_Final(digest, &c1);
	blk_SHA1_Block(&c2, (const unsigned int*)ctx2);
	c2.size = 64;
	blk_SHA1_Pass(&c2, (unsigned int*)digest);
	memcpy(res, digest, 20);
}

void HMAC_EVP_SHA1_fixed(const uint8_t* key, const uint8_t* data, uint32_t* res)
{
	int klen = 32, dlen = 100;
	
	uchar ctx1[64];
	uchar ctx2[64];
	int i;
	for (i = 0; i < 32; i++)
	{
		ctx1[i] = key[i] ^ 0x36;
		ctx2[i] = key[i] ^ 0x5c;
	}
	for (; i < 64; i++)
	{
		ctx1[i] = 0x36;
		ctx2[i] = 0x5c;
	}

	const uint32_t ch[5] = {
		0x67452301,
		0xefcdab89,
		0x98badcfe,
		0x10325476,
		0xc3d2e1f0,
	};

	uint32_t a[2][5];
	SHA1_16x5(ch, (const uint32_t*)ctx1, a[0]);
	SHA1_16x5(ch, (const uint32_t*)ctx2, a[1]);
	//uint32_t* q = (uint32_t*)&c1.h0;
	for (int i = 0; i < 5; i++)
	{
		a[0][i] = _byteswap_ulong(a[0][i]);
		a[1][i] = _byteswap_ulong(a[1][i]);
	}

	uint32_t temp[5];
	SHA1_16x5(a[0], (const uint32_t*) data, temp);
	for (int i = 0; i < 5; i++)
		a[0][i] = _byteswap_ulong(temp[i]);

	uint8_t pad[64];
	memcpy(pad, data + 64, 36);
	pad[36] = 0x80;
	for (int i = 37; i < 56; i++)
		pad[i] = 0;

	unsigned int padlen[2];
	int s = 164;
	padlen[0] = htonl((uint32_t)(s >> 29));
	padlen[1] = htonl((uint32_t)(s << 3));
	*(int*)(pad + 56) = padlen[0];
	*(int*)(pad + 60) = padlen[1];
	SHA1_16x5(a[0], (uint32_t*) pad, temp);
	SHA1_5x5(a[1], temp, (uint32_t*)res);
	for (int i = 0; i < 5; i++)
		res[i] = htonl(res[i]);
}

unsigned char* g_buf;
int g_count = 0;

void sha1_transform(unsigned int* ctx, const unsigned int *data);

void sha1_block(const unsigned int* pc1, const unsigned int* pc2,
	const unsigned int* pad, 
	unsigned int* pmk)
{
	int npasses = 4096;
	unsigned int  out[5], data[5];
	
	for (int i = 0; i < 5; i++)
		out[i] = data[i] = _byteswap_ulong(pad[i]);
	
	for (int i = 1; i < npasses; i++)
	{
		unsigned int ctx[5], ctx2[5];
		for (int j = 0; j < 5; j++)
			ctx[j] = pc1[j];
		sha1_transform(ctx, data);
		for (int j = 0; j < 5; j++)
			ctx2[j] = pc2[j];
		sha1_transform(ctx2, ctx);
		for (int j = 0; j < 5; j++)
		{
			data[j] = ctx2[j];
			out[j] ^= ctx2[j];
		}
	}
	for (int i = 0; i < 5; i++)
		pmk[i] = _byteswap_ulong(out[i]);
}

//https://www.ins1gn1a.com/understanding-wpa-psk-cracking/
//https://security.stackexchange.com/questions/66008/how-exactly-does-4-way-handshake-cracking-work
void calc_ptk(const u8* key, int klen, const char* essid_pre, unsigned char* ptk, const uchar* pke)
{
	blk_SHA_CTX sha1_ctx;
	unsigned int v_ipad[5], v_opad[5];

	u8 essid[2][33 + 4];
	memset(essid[0], 0, 33 + 4);
	memcpy(essid[0], essid_pre, strlen(essid_pre));
	memset(essid[1], 0, 33 + 4);
	memcpy(essid[1], essid_pre, strlen(essid_pre));
	int slen = strlen(essid_pre) + 4;
	essid[0][slen - 1] = '\1';
	essid[1][slen - 1] = '\2';

	int i, j;
	uchar ctx1[64], ctx2[64];
	for (i = 0; i < klen; i++)
	{
		ctx1[i] = key[i] ^ 0x36;
		ctx2[i] = key[i] ^ 0x5c;
	}
	for (; i < 64; i++)
	{
		ctx1[i] = 0x36;
		ctx2[i] = 0x5c;
	}

	blk_SHA_CTX c1, c2;
	blk_SHA1_Init(&c1);
	blk_SHA1_Init(&c2);

	blk_SHA1_Block(&c1, (const unsigned int*)ctx1);
	c1.size = 64;
	blk_SHA1_Block(&c2, (const unsigned int*)ctx2);
	c2.size = 64;

	memcpy(v_ipad, &c1.h0, 5 * 4);
	memcpy(v_opad, &c2.h0, 5 * 4);

	unsigned char* data1 = (unsigned char*)essid[0];
	unsigned char* data2 = (unsigned char*)essid[1];

	unsigned char pmk[40];

	blk_SHA_CTX c3, c4;
	memcpy(&c3, &c1, 28);
	memcpy(&c4, &c2, 28);

	uchar digest[2][64];

	blk_SHA1_Update(&c1, data1, slen);
	blk_SHA1_Update(&c3, data2, slen);

	blk_SHA1_Final(digest[0], &c1);
	blk_SHA1_Final(digest[1], &c3);

	blk_SHA1_Pass(&c2, (unsigned int*)digest[0]);
	blk_SHA1_Pass(&c4, (unsigned int*)digest[1]);
	//		if (n == 0)
	//			printf("=> %08x %08x\n", *(int*)(&digest[0][0]), *(int*)(&digest[0][4]));
	memcpy(pmk, digest[0], 20);
	memcpy(pmk+20, digest[1], 20);
	
	//sha1_block(v_ipad, v_opad, (unsigned int*)pmk);
	//sha1_block(v_ipad, v_opad, (unsigned int*)(pmk+20));
	//sha1_block(v_ipad, v_opad, digest[0], digest[1], pke, 
	unsigned char temp[40];
	sha1_block(v_ipad, v_opad, (const unsigned int*)(digest[0]), (unsigned int*)pmk);
	sha1_block(v_ipad, v_opad, (const unsigned int*)(digest[1]), (unsigned int*)(pmk+20));
	HMAC_EVP_SHA1(pmk, 32, pke, 100, ptk, 0);
}

void calc_ptk_begin(vector<u8>& keys,
	const char* essid_pre, uint8_t* fpga_in_buf)
	//, uint8_t* ptk, const uint8_t* pke)
{
	blk_SHA_CTX sha1_ctx;
	u8 essid[2][64];
	memset(essid[0], 0, 33 + 4);
	memcpy(essid[0], essid_pre, strlen(essid_pre));
	memset(essid[1], 0, 33 + 4);
	memcpy(essid[1], essid_pre, strlen(essid_pre));
	int slen = strlen(essid_pre) + 4;
	essid[0][slen - 1] = '\1';
	essid[1][slen - 1] = '\2';
	essid[0][slen] = 0x80;
	essid[1][slen] = 0x80;
	unsigned int padlen[2];
	for (int i = slen + 1; i < 56; i++)
	{
		essid[0][i] = 0;
		essid[1][i] = 0;
	}
	int s = slen + 64;

	padlen[0] = htonl((uint32_t)(s >> 29));
	padlen[1] = htonl((uint32_t)(s << 3));
	*(int*)(essid[0] + 56) = padlen[0];
	*(int*)(essid[1] + 56) = padlen[0];
	*(int*)(essid[0] + 60) = padlen[1];
	*(int*)(essid[1] + 60) = padlen[1];

	int nk = keys.size() / 64;
	int workset = 1000 * nInst * 120 * 4;

	auto tn = std::chrono::high_resolution_clock::now();
	double f1 = std::chrono::duration_cast<std::chrono::milliseconds>(tn.time_since_epoch()).count() * 0.001;

	const uint32_t ch[5] = {
		0x67452301,
		0xefcdab89,
		0x98badcfe,
		0x10325476,
		0xc3d2e1f0,
	};
#pragma omp parallel for
	for (int thr = 0; thr < 2; thr++)
	{
		int grp = 0, inst = 0, row = thr;
		uchar ctx1[64], ctx2[64];
		int prev_len = 0;
		for (int i = 0; i < 64; i++)
		{
			ctx1[i] = 0x36;
			ctx2[i] = 0x5c;
		}

		for (int m = thr; m < nk; m += 2)
		{
			int i, j;

			uint32_t* vdata = (uint32_t*)(fpga_in_buf + (grp * nInst + inst) * 120 * 60 + row * 20);
			uint32_t* opad = (uint32_t*)(fpga_in_buf + (grp * nInst + inst) * 120 * 60 + 120 * 20 + row * 20);
			uint32_t* ipad = (uint32_t*)(fpga_in_buf + (grp * nInst + inst) * 120 * 60 + 120 * 40 + row * 20);
			uint32_t* vdata2 = (uint32_t*)(fpga_in_buf + ((grp + 500) * nInst + inst) * 120 * 60 + row * 20);
			uint32_t* opad2 = (uint32_t*)(fpga_in_buf + ((grp + 500) * nInst + inst) * 120 * 60 + 120 * 20 + row * 20);
			uint32_t* ipad2 = (uint32_t*)(fpga_in_buf + ((grp + 500) * nInst + inst) * 120 * 60 + 120 * 40 + row * 20);

			for (i = 0; i < 64; i++)
			{
				if (keys[m * 64 + i] == 0)
					break;
				ctx1[i] = keys[m * 64 + i] ^ 0x36;
				ctx2[i] = keys[m * 64 + i] ^ 0x5c;
			}
			int len = i;

			for (; i < prev_len; i++)
			{
				ctx1[i] = 0x36;
				ctx2[i] = 0x5c;
			}
			prev_len = len;

			uint32_t a[2][5];
			SHA1_16x5(ch, (const uint32_t*)ctx1, a[0]);
			SHA1_16x5(ch, (const uint32_t*)ctx2, a[1]);
			//uint32_t* q = (uint32_t*)&c1.h0;
			for (int i = 0; i < 5; i++)
			{
				a[0][i] = _byteswap_ulong(a[0][i]);
				a[1][i] = _byteswap_ulong(a[1][i]);
			}

			memcpy(ipad, a[0], 5 * 4);
			memcpy(ipad2, a[0], 5 * 4);
			memcpy(opad, a[1], 5 * 4);
			memcpy(opad2, a[1], 5 * 4);

			uint32_t temp[5];
			SHA1_16x5(a[0], (const uint32_t*)essid[0], temp);
			SHA1_5x5(a[1], temp, vdata);

			SHA1_16x5(a[0], (const uint32_t*)essid[1], temp);
			SHA1_5x5(a[1], temp, vdata2);

			row += 2;
			if (row >= 120)
			{
				row = thr;
				inst++;
			}
			if (inst == nInst)
			{
				inst = 0;
				grp++;
			}
		}
	}
	tn = std::chrono::high_resolution_clock::now();
	double f2 = std::chrono::duration_cast<std::chrono::milliseconds>(tn.time_since_epoch()).count() * 0.001;
	printf("Precompute: %f\n", f2 - f1);
	return fpga_in_buf;
}

void fpga_submit_job(uint8_t* job)
{
	while (true)
	{
		int flags = *(int*)(buf_cfg + 8);
		int ext_mode = (flags >> 5) & 3;
		int write_pos = *(int*)(buf_cfg);
		if (ext_mode == 2 && write_pos == 2400000 * nInst)
			break;
		struct timespec ts;
		ts.tv_sec = 0;
		ts.tv_nsec = 100000000;
		nanosleep(&ts, 0);
	}

	memcpy(buf_in, fpga_in_buf, WORK_SIZE_IN);

	static int counter = *(int*)(buf_cfg + 12);
	counter++;
	//memset(buf_in + 2 * 3 * 120 * 60, 0x1, 20);
	*(int*)(buf_cfg + 12) = counter;
	for (int i = 0; i < 1000; i++);
	*(int*)(buf_cfg + 16) = counter;

	struct timespec ts;
	ts.tv_sec = 0;
	ts.tv_nsec = 10000;
	nanosleep(&ts, 0);
}

void fpga_retrieve_job(uint8_t* result)
{
	while (true)
	{
		int flags = *(int*)(buf_cfg + 8);
		int ext_mode = (flags >> 5) & 3;
		int write_pos = *(int*)(buf_cfg);
		if (ext_mode == 2 && write_pos == 2400000 * nInst)
			break;
		struct timespec ts;
		ts.tv_sec = 0;
		ts.tv_nsec = 100000000;
		nanosleep(&ts, 0);
	}
	memcpy(result, buf_out, WORK_SIZE_OUT);
}

void calc_ptk_end(uint8_t* data, uint8_t* pke, hccapx_t* packet, vector<u8>& keyspace)
{
/*	
	for (int m = 0; m < nk; m++)
	{
		sha1_block((const unsigned int*)(p_pad1 + m * 20), (const unsigned int*)(p_pad2 + m * 20), (const unsigned int*)(p_digest1 + m * 20), (unsigned int*) (p_out1 + m * 20));
		sha1_block((const unsigned int*)(p_pad1 + m * 20), (const unsigned int*)(p_pad2 + m * 20), (const unsigned int*)(p_digest2 + m * 20), (unsigned int*)(p_out2 + m * 20));
	}
*/	
	tn = std::chrono::high_resolution_clock::now();
	double f3 = std::chrono::duration_cast<std::chrono::milliseconds>(tn.time_since_epoch()).count() * 0.001;
#pragma omp parallel for
	for (int m = 0; m < nk; m++)
	{
		uint32_t temp[10];
		uint32_t ptk[5];
		for (int i = 0; i < 5; i++)
			temp[i] = byteswap((unsigned char*)data + m*20 + i*4);
		for (int i = 0; i < 3; i++)
			temp[5+i] = byteswap((unsigned char*)data + m *20 + i*4 + 500*nInst*120*20);
		HMAC_EVP_SHA1_fixed((uint8_t*)temp, pke, ptk);

		unsigned char mic[20];
		//unsigned char ptk[20];
		//- 128 bits -.- 128 bits -.- 128 bits -.- 64 bits -.- 64 bits -
		// | KCK      |   KEK         | TK        | MIC Tx | MIC Rx |
		//calc_ptk(&keyspace[n * 64], 10, essid, ptk, pke);
		if (packet->keyver == 1)
			HMAC_EVP_MD5(ptk + n * 20, 16, packet->eapol, packet->eapol_len, mic, NULL);
		else
			HMAC_EVP_SHA1(ptk + n * 20, 16, packet->eapol, packet->eapol_len, mic, NULL);
		if (memcmp(mic, packet->keymic, 16) == 0)
		{
			printf("SOLUTION FOUND: %s\n", m, (const char*) &keyspace[m*64]);
		}
	}
	tn = std::chrono::high_resolution_clock::now();
	double f4 = std::chrono::duration_cast<std::chrono::milliseconds>(tn.time_since_epoch()).count() * 0.001;
//	printf("Finalize: %f\n", f4 - f3);
	/*
	delete[] p_pad1;
	delete[] p_pad2;
	delete[] p_digest1;
	delete[] p_digest2;
	delete[] p_out1;
	delete[] p_out2;
	*/
}

#include <chrono>

int nb_tried = 0;
int do_crack_wpa( hccapx_t* packet )
{
	char  essid[36];

	unsigned char pke[100*4];

	//struct WPA_data* data;
	//struct AP_info* ap;
	int threadid=0;
	int ret=0;
	int i, slen;

	nb_tried = 0;


	if (packet->keyver == 1)
	{
		printf("WPA/MD5 not implemented\n");
		return 0;
	}
	if (packet->essid_len == 0 || packet->essid[0]==0)
	{
		printf("Blank ESSID\n");
		return 0;
	}
	//cpuinfo.simdsize = 1;

	memcpy(essid, packet->essid, 32);
	//g_essid = essid;
//	init_ssecore(threadid);

	/* pre-compute the key expansion buffer */
	memcpy( pke, "Pairwise key expansion", 23 );
	if (memcmp(packet->mac_sta, packet->mac_ap, 6) < 0)	{
		memcpy( pke + 23, packet->mac_sta, 6 );
		memcpy( pke + 29, packet->mac_ap, 6 );
	} else {
		memcpy( pke + 23, packet->mac_ap, 6 );
		memcpy( pke + 29, packet->mac_sta, 6 );
	}
	if( memcmp( packet->nonce_sta, packet->nonce_ap, 32 ) < 0 ) {
		memcpy( pke + 35, packet->nonce_sta, 32 );
		memcpy( pke + 67, packet->nonce_ap, 32 );
	} else {
		memcpy( pke + 35, packet->nonce_ap, 32 );
		memcpy( pke + 67, packet->nonce_sta, 32 );
	}
	for (i = 1; i< 4; i++)
		memcpy(pke + i * 100, pke, 100);
	pke[99] = 0;
	pke[199] = 1;
	pke[299] = 2;
	pke[399] = 3;

	/* receive the essid */

	slen = strlen(essid) + 4;

//	init_atoi();
	auto t = std::chrono::high_resolution_clock::now();

	const int nKeysPerBatch = 500*nInst*120;// 16384 * 8;
	unsigned char* ptk = new unsigned char[20 * nKeysPerBatch];
	//unsigned char* pmk_buf;
	//cudaHostAlloc(&pmk_buf, 40 * nKeysPerBatch, cudaHostAllocPortable);
	//vector<uchar> pmk_buf;
	//pmk_buf.resize(40 * nKeysPerBatch);
	//uchar pmk_buf[40];
	//pmk_buf
		//(40 * nKeysPerBatch);
	double fn0 = std::chrono::duration_cast<std::chrono::milliseconds>(t.time_since_epoch()).count() * 0.001;
	vector<u8> keyspace[2];
	uint8_t* fpga_in_buf[2];
	uint8_t* fpga_out_buf[2];
	size_t szFpgaIn = nInst * 4 * 120 * 60;
	size_t szFpgaOut = nInst * 4 * 120 * 20;
	fpga_in_buf[0] = new uint8_t[szFpgaIn];
	//fpga_in_buf[1] = new uint8_t[szFpgaIn];
	fpga_out_buf[0] = new uint8_t[szFpgaOut];
	//fpga_out_buf[1] = new uint8_t[szFpgaOut];

	while( 1 )
	{
		keyspace[0].clear();
	//	printf("<%.3f>  Start reading passphrases\n", fn-fn0);
		read_passphrases(keyspace[0], nKeysPerBatch);
		printf("%s\n", &keyspace[0][0]);
		printf("Passphrases: %f\n", f1 - fn);
		int nkeys = keyspace[0].size() / 64;
		//calc_ptk_array(keyspace, essid, ptk, pke);

		calc_ptk_begin(keyspace[0], essid, fpga_in_buf[0]);
		if(nb_tried!=0)
			fpga_retrieve_job(fpga_out_buf[0]);
		fpga_submit_job(fpga_in_buf[0]);
		if(nb_tried!=0)
			calc_ptk_end(fpga_out_buf[0], pke, packet, keyspace[1]);
		nb_tried++;

		if (nb_tried > 1 && keyspace[0].empty())
			break;

		keyspace[0].swap(keyspace[1]);
		//if (!(nb_tried % 10))
		{
			auto t1 = std::chrono::high_resolution_clock::now();
			//auto timeElapsed = std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t).count();
					
//				printf("%d\n", std::chrono::duration_cast<std::chrono::milliseconds>(t1.time_since_epoch()));
//				printf("%d\n", std::chrono::duration_cast<std::chrono::milliseconds>(t1-t));
//				printf("%d\n", std::chrono::duration_cast<std::chrono::milliseconds>(t1 - t).count());
			fn = std::chrono::duration_cast<std::chrono::milliseconds>(t1.time_since_epoch()).count() * 0.001;
			double timeElapsed = fn - fn0;
			double rate = nb_tried*nKeysPerBatch / double(timeElapsed);
			printf("%d keys tested in %.3f s (%.1f keys/s)\n", nb_tried * nKeysPerBatch, timeElapsed, rate);
		}
//		if (nb_tried > 100)
//			return ret;
	}
	//cudaFreeHost(pmk_buf);
	return ret;
}

hccapx_t* read_hccap(const char* fn, int idx=0)
{
	FILE* fc;
	fc=fopen( fn, "r");
	if (fc == 0)
	{
		printf("ERROR: failed to open hccapx for reading\n");
		exit(-1);
	}
	fseek(fc, 0, SEEK_END);
	int n = ftell(fc) / 393;
	rewind(fc);
	if (idx >= n)
	{
		fclose(fc);
		return 0;
	}

	hccapx_t* hccapx = new hccapx_t;

	if (idx != 0)
		fseek(fc, idx * 393, SEEK_SET);
	fread(hccapx, sizeof(hccapx_t), 1, fc);
	fclose(fc);

	uchar* p = hccapx->essid;
	for (int i = 0; i < hccapx->essid_len; i++)
	{
		if (p[i] < 32 || p[i]>127)
		{
			delete hccapx;
			return 0;
		}
	}
	return hccapx;
}	

int main(int argc, char** argv) {

	int fd;
	//omp_set_num_threads(2);
	bool bReset = true;// (argc >= 2 && !strcmp(argv[1], "-reset"));
	//printf("=== HPS ===\n");
	fflush(stdout);
	// map the address space for the LED registers into user space so we can interact with them.
	// we'll actually map in the entire CSR span of the HPS since we want to access various registers within that span

	if ((fd = open("/dev/mem", (O_RDWR | O_SYNC))) == -1) {
		printf("ERROR: could not open \"/dev/mem\"...\n");
		return(1);
	}

	buf_in = (char*)mmap(NULL, WORK_SIZE_IN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, WORK_BUFFER_IN);
	if (buf_in == MAP_FAILED) {
		printf("ERROR: mmap() failed...\n");
		close(fd);
		return(1);
	}
	buf_out = (char*)mmap(NULL, WORK_SIZE_OUT, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, WORK_BUFFER_OUT);
	if (buf_in == MAP_FAILED) {
		printf("ERROR: mmap() failed 2\n");
		close(fd);
		return(1);
	}
	buf_cfg = (char*)mmap(NULL, WORK_SIZE_CFG, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, CONFIG_MEM);
	if (buf_in == MAP_FAILED) {
		printf("ERROR: mmap() failed 3\n");
		close(fd);
		return(1);
	}
	int rs = 6, enable = 7, d0 = 2, d1 = 3, d2 = 4, d3 = 5;

	// set all pins to OUT
	*(int*)(buf_cfg + 0x404) = 0xFF;

	LiquidCrystal lcd(6, 7, 2, 3, 4, 5);

	// set up the LCD's number of columns and rows:
	lcd.begin(16, 2);
	//lcd.write(0x41);

	// Print a message to the LCD.
	//lcd.print("hello, world!");
	const char* capfn = (argc>1) ? argv[1] : "sample.hccapx";
	hccapx_t* cap = read_hccap(capfn, 0);
	do_crack_wpa(cap);
//	return 0;

	if (munmap(buf_in, WORK_SIZE_IN) != 0) {
		printf("ERROR: munmap() failed...\n");
		close(fd);
		return(1);
	}
	if (munmap(buf_out, WORK_SIZE_OUT) != 0) {
		printf("ERROR: munmap() failed...\n");
		close(fd);
		return(1);
	}
	if (munmap(buf_cfg, WORK_SIZE_CFG) != 0) {
		printf("ERROR: munmap() failed...\n");
		close(fd);
		return(1);
	}

	close(fd);

	return(0);
}
