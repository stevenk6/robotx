#include <SoftwareSerial.h>

SoftwareSerial XBee(2, 3);
//This sets pins 2 and 3 on the arduino to be used
//as extra TX and RX. These are the pins the XBee used to send serial communication

int j=0;
void setup()
{
    pinMode(13,OUTPUT);
    pinMode(12,OUTPUT);
    XBee.begin(9600);
    Serial.begin(9600);
//Ensure that both receiver/transmitter are both same baud 
}
 
void loop()
{
  j=XBee.read();
    if (j==1)
   { 
    //Turns ON
    digitalWrite(13,HIGH);
    digitalWrite(12,LOW);
    Serial.print(j);
    delay(100);
   }
    if (j==2)
    {
    //Turns OFF
    digitalWrite(13,LOW);
    digitalWrite(12,HIGH);
    Serial.print(j);
    delay(100);
  }
}

//If no communication comes in then the it will not read 0 or 1 and would shutoff
