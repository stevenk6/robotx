#include <SoftwareSerial.h>

SoftwareSerial XBee(2,3);
//This sets pins 2 and 3 on the arduino to be used
//as extra TX and RX. These are the pins the XBee used to send serial communication
//XBee assigns the pins 2 and 3 from now on and used just as serial.Read()
int stat;

void setup()
{
  pinMode(12,INPUT);
  pinMode(13,OUTPUT);
  XBee.begin(9600);
  Serial.begin(9600);
}
//Ensure that both receiver/transmitter are both same baud rate
//High is ON
//LOW is KILL
void loop()
{
  stat=digitalRead(12);
  //ON
  if (stat==LOW)
  {
    XBee.write(1);
    Serial.println(1);
    delay(100);
  }
  else if (stat==HIGH)
  {
    //KILL
    XBee.write(2);
    Serial.println(2);
    delay(100);
  }
}
