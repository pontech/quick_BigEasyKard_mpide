// MPIDE 20140316, github/orgs/pontech/pic32lib commit dd7b94913134b7352a565b89fb3889459f9731f7
#include <Wire.h>
 
#include "pic32lib/Quick.h"
#include "pic32lib/TokenParser.h"
#include "pic32lib/Cron.h"
#include "pic32lib/StepAndDirection.h"
 
Quick q;
Cron cron(micros);
 
#line 20 "quick_BigEasyKard_mpide.pde"
 
#define XAxisKard 2
StepAndDirection xaxis(2, XAxisKard, Variant(5, -6), "/?", "C" ); // motor id 0, card position 3
 
// inputs
#define XAxisHome c0p0
 
TokenParser usb(&Serial);
 
void flash() {
  Cron::CronDetail *self = cron.self();
 
  digitalWrite(led1, self->temp);
  digitalWrite(led2, !self->temp);
 
  self->temp ^= 1;
  self->yield = micros() + 1000000;
}
 
void setCurrentLimit(us8 cardNumber, us8 wr, char *kard_rev) {
  for(int i = 0; i < 6; i++) {
    pinMode(KardIO[i][5], OUTPUT);
    digitalWrite(KardIO[i][5], HIGH);
  }
  if( strncmp(kard_rev, "C", 1) == 0) {
    setCurrentLimitRevC(wr);
  }
  else if( strcmp(kard_rev, "D") == 0) {
    setCurrentLimitRevD(cardNumber, wr);
  }
}
void setCurrentLimitRevC(int wr) {
  Wire.beginTransmission(0x2F); // transmit to device #94 (0x5e) 92
  // device address is specified in datasheet
  Wire.send(0x00);              // sends instruction byte  
  Wire.send(wr);               // sends potentiometer value byte
  Wire.endTransmission();       // stop transmitting
 
  Wire.beginTransmission(0x2F);
  Wire.send(0x42);
  Wire.endTransmission();
}
 
void setCurrentLimitRevD(us8 cardNumber, us8 wr) {
  us8 acr = 0x40; // 0x40 enable, 0x00 to shutdown
  digitalWrite(KardIO[cardNumber][5], LOW);
 
  Wire.beginTransmission(0x50); // transmit to device address byte
  Wire.send(0x00);              // sends memory address byte  
  Wire.send(wr);                // sends potentiometer value byte
  Wire.endTransmission();       // stop transmitting
 
  Wire.beginTransmission(0x50); // transmit to device address byte
  Wire.send(0x10);              // sends memory address byte  
  Wire.send(acr);               // 0x40 enable, 0x00 to shutdown
  Wire.endTransmission();       // stop transmitting
}
 
void setup() {
  Serial.begin(115200); // enable usb communication
  Wire.begin();
 
  setCurrentLimit(XAxisKard,15,xaxis.getKardRev()); // sets current limit on big easy cards
 
  q.kardConfig(0, 0x1f); // configure card 0 as input
  //q.kardConfig(1, 0x00); // configure card 1 as output
 
  // Set XAxisHome to INPUT to use as home seneor
  //pinMode(XAxisHome,INPUT);
  // Set XAxisHome to OUTPUT driven LOW if home sensor is not connected
  pinMode(XAxisHome,OUTPUT);
  digitalWrite(XAxisHome,LOW);
 
  xaxis.setConversion(1); // steps per unit, mm
  xaxis.setLimits(0, 0); // limit range in units, 0 - 1000mm
  xaxis.setMicrostepsPerStep(2); // Initial step mode
  xaxis.setHomeSensorPersistent(XAxisHome, true, false);
  xaxis.setSigmoid(Variant(5, 2), Variant(1, 3), Variant(25, 0), Variant(3, 0));
 
  cron.add(flash);
 
  ConfigIntTimer3(T3_INT_ON | T3_INT_PRIOR_6);
  OpenTimer3(T3_ON | T3_PS_1_4, 100); // 5us period (measured with scope and calculated [1/(80MHz/4) * 100 = 5us] 
}
 
void loop() {
  cron.scheduler();
 
  if(usb.scan()) {
    q.command(usb);
    xaxis.command(usb);
 
    if(usb.compare("currentx")) {
      usb.nextToken();
      setCurrentLimit(XAxisKard, usb.toVariant().toInt(), xaxis.getKardRev());
      usb.println("OK");
    }
  }
}
 
extern "C"
{
  void __ISR(_TIMER_3_VECTOR,ipl6) StepAndDirectionInterrupt(void)
  {
    xaxis.sharedInterrupt(); //comment out is using with unsharedInterruptService
    mT3ClearIntFlag();  // Clear interrupt flag
  }
} // end extern "C"
