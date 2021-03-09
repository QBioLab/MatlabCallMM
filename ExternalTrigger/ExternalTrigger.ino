/*********************************************************
* External trigger by Serial Port
*    Ver | Commit
*    0.1 | H.F. first version
*  Usage: char '1' to star, char'0' close channel 1
*  https://www.arduino.cc/reference/en/language/functions/time/millis/
*  Todo: 
*  1. acess pulse number
*/

int incomingByte = 0; // for incoming serial data
const unsigned int ch1 = 3; // pin3
const unsigned int z_num = 20;
unsigned long int timer0 = millis();
unsigned int t_gap = 390; //150ms time gap

void setup() {
  Serial.begin(57600); // opens serial port, sets data rate

  // Turn on build-in pull-up resistors
  // PORTC = PORTC | B00111111;
  pinMode(ch1, OUTPUT);
  digitalWrite(ch1, LOW);
}

void loop() {
  // send data only when you receive data:
  if (Serial.available() > 0) {
    // read the incoming byte:
    incomingByte = Serial.read();

    //Serial.println(incomingByte); 
    if ( incomingByte & 0x0F) { // If incomingByte > 1, turn channel 1 on 
      // trigger camera in certain time gap
      for(int i=0; i<z_num; i++){
        timer0 = millis();
        digitalWrite(ch1, HIGH);
        delay(10); // sleep 1ms
        digitalWrite(ch1, LOW);
        while(millis() - timer0 < t_gap){
          delay(1);
          }
      }
   } else {                    // If incomingByte = 0, turn channel 1 off
      digitalWrite(ch1, LOW); 
    }
  }
}
