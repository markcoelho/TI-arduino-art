#include <Wire.h>  // comunicação i2c
#include <Servo.h>  // controle do servo
#include <VL53L1X.h>  // sensor laser

VL53L1X laser;  // objeto do sensor
Servo servo;  // objeto do servo

// pinos do sensor ultrassônico
const int trig = 9;  // pino trigger
const int echo = 10;  // pino echo

// variáveis do servo
int pos = 90;  // posição atual
int passo = 3;  // passo do movimento
unsigned long ultimo = 0;  // último movimento
const int espera = 10;  // tempo entre movimentos
const int min = 20;  // limite mínimo
const int max = 160;  // limite máximo

void setup() {
  Serial.begin(115200);  // inicia serial
  
  servo.attach(11);  // servo no pino 11
  servo.write(pos);  // posição inicial
  
  // configura ultrassom
  pinMode(trig, OUTPUT);
  pinMode(echo, INPUT);
  
  Wire.begin();  // inicia i2c
  Wire.setClock(400000);  // clock rápido
  
  // testa sensor laser
  if (!laser.init()) {
    Serial.println("erro no laser");
    while (1);  // trava se falhar
  }
  
  // configura laser
  laser.setDistanceMode(VL53L1X::Long);  // modo longo alcance
  laser.setMeasurementTimingBudget(50000);  // tempo de medição
  laser.startContinuous(50);  // leitura contínua
}

void loop() {
  // atualiza posição do servo
  if (millis() - ultimo >= espera) {
    pos += passo;  // move servo
    servo.write(pos);  // envia posição
    
    // inverte direção nos limites
    if (pos >= max || pos <= min) {
      passo *= -1;
    }
    
    ultimo = millis();  // atualiza tempo
  }

  // lê ultrassom
  float us = mede_us();
  
  // lê laser
  laser.read();
  float dist = laser.ranging_data.range_mm;
  
  // trata erro
  if (laser.timeoutOccurred() || dist > 4000) {
    dist = 0;
  }

  // envia dados
  // formato: ultrassom,laser,angulo
  Serial.print(us);
  Serial.print(",");
  Serial.print(dist);
  Serial.print(",");
  Serial.println(pos);
}

// função do ultrassom
float mede_us() {
  // envia pulso
  digitalWrite(trig, LOW);
  delayMicroseconds(2);
  digitalWrite(trig, HIGH);
  delayMicroseconds(10);
  digitalWrite(trig, LOW);
  
  // mede eco
  long tempo = pulseIn(echo, HIGH);
  return tempo * 0.034 / 2;  // converte para cm
}