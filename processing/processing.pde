import processing.serial.*;
import processing.sound.*;

// variaveis para comunicar com o arduino
Serial portaSerial;          // porta serial
int angulo = 90;         // angulo do servo (0-180)
int distanciaUltrassonica = 0;     // distancia do sensor
int distanciaLaser = 0;  // distancia do laser

// variaveis para analisar o som
AudioIn microfone;            // microfone
Amplitude analisador;     // mede a amplitude do som
FFT fft;                // analisa frequencias
float nivelSom = 0;   // volume atual
float limiarSom = 0.05;  // limite para detetar som
float limiarPalmas = 0.05;    // limite para palmas
int esperaPalmas = 0;         // tempo entre palmas

// sons que vao tocar
SoundFile ambiente;     // som de fundo
SoundFile som1;      // duas musicas
float volumeSom1 = 0;        // volume da musica 1
float volumeSom2 = 0;        // volume da musica 2
float velocidadeFade = 0.02;        // velocidade do fade
float tamanhoMaximo = 3.0; // tamanho maximo das particulas

// ondas para ver o som
ArrayList<Onda> ondas = new ArrayList<Onda>();  // lista de ondas
float velocidadeOnda = 3.0;              // velocidade das ondas
float raioMaximoOnda;                // tamanho maximo
float forcaOnda = 50.0; // força da onda
float corOffset = 0;                // muda as cores

// sistema de particulas
int numParticulas = 1500;            // total de particulas
Particula[] particulas = new Particula[numParticulas]; // array de particulas
float escalaRuido = 300;             // escala do ruido
float forcaRuido = 8;            // força do ruido
float atracaoBase = 0.8;    // atração normal
float atracaoMaxima = 3.0;          // atração maxima
float raioAtracao = 200;            // area de influencia
float distanciaMinima = 20;             // distancia minima
float raioColisao = 5;          // tamanho para colidir
float forcaColisao = 0.5;      // força da colisao

// quando clicas no rato
float forcaRepulsao = 5.0;      // força para afastar
int duracaoRepulsao = 50;         // tempo do efeito
int tempoRepulsao = 0;             // contador

// cores usadas
color[] cores = {                 // paleta de cores
  color(0, 21, 36),    // preto
  color(21, 97, 109),  // azul
  color(247, 125, 0),  // laranja
  color(120, 41, 15),  // castanho
  color(255, 236, 209) // bege
};
color corAtracao = cores[0];    // cor normal
color corRepulsao;                  // cor quando repeles
color corFundo = cores[4]; // cor de fundo
float velocidadeMudancaCor = 0.1;   // velocidade para mudar cores

// suaviza o movimento
PVector centroSuavizado;

void setup() {
  fullScreen();
  smooth(8);  // melhora a qualidade
  
  // começa no centro
  centroSuavizado = new PVector(width/2, height/2);
  
  // liga ao arduino
  String nomePorta = Serial.list()[0]; // escolhe a porta
  portaSerial = new Serial(this, nomePorta, 115200);
  portaSerial.bufferUntil('\n');  // espera por dados
  
  // configura o microfone
  microfone = new AudioIn(this, 0);  // usa o microfone
  microfone.start();
  analisador = new Amplitude(this);
  analisador.input(microfone);
  
  // prepara para detetar palmas
  fft = new FFT(this, 1024);  // analisa frequencias
  fft.input(microfone);
  
  // carrega os sons
  ambiente = new SoundFile(this, "ambient.mp3");
  ambiente.loop();  // repete
  ambiente.amp(0.3); // volume
  
  som1 = new SoundFile(this, "1.mp3");
  som1.loop();  // repete
  som1.amp(0);  // começa mudo
  
  // calcula o tamanho maximo das ondas
  raioMaximoOnda = dist(0, 0, width/2, height/2);
  
  // cria as particulas
  for (int i = 0; i < numParticulas; i++) {
    if (random(1) > 0.3) {
      // maioria aparece aleatoriamente
      particulas[i] = new Particula(random(width), random(height));
    } else {
      // algumas aparecem no centro
      particulas[i] = new Particula(width/2 + random(-50, 50), height/2 + random(-50, 50));
    }
  }
  background(corFundo);  // pinta o fundo
}

void draw() {
  // fundo com transparencia para rastos
  noStroke();
  fill(corFundo, 255);
  rect(0, 0, width, height);
  
  // conta o tempo entre palmas
  if (esperaPalmas > 0) {
    esperaPalmas--;
  }
  
  // escolhe cor aleatoria para repulsao
  corRepulsao = cores[int(random(cores.length))];
  
  // conta o tempo da repulsao
  if (tempoRepulsao > 0) {
    tempoRepulsao--;
  }
  
  // mede o volume
  nivelSom = analisador.analyze();
  
  // deteta palmas (som agudo)
  fft.analyze();
  float somAgudo = 0;
  for (int i = 40; i < 60; i++) { // frequencias altas
    somAgudo += fft.spectrum[i];
  }
  
  // se houve uma palma
  if (somAgudo > limiarPalmas && esperaPalmas == 0) {
    // muda a cor de fundo
    color novaCor = corFundo;
    while (novaCor == corFundo) {
      novaCor = cores[int(random(cores.length))];
    }
    corFundo = novaCor;
    esperaPalmas = 30; // espera um pouco
  }
  
  // se o som for alto, cria onda
  if (nivelSom > limiarSom) {
    corOffset = (corOffset + 15) % 360; // muda cor
    float corOnda = (corOffset + frameCount * 0.5) % 360; // cor que muda
    ondas.add(new Onda(width/2, height/2, nivelSom, corOnda));
  }
  
  // atualiza as ondas
  for (int i = ondas.size() - 1; i >= 0; i--) {
    Onda o = ondas.get(i);
    o.atualizar();
    if (o.terminada()) {
      ondas.remove(i);
    }
  }

  // calcula posição com base nos sensores
  float distanciaMedia = (distanciaUltrassonica + distanciaLaser) / 2.0;
  float distanciaMapeada = map(distanciaMedia, 0, 1000, 0, height * 0.8);
  float anguloRad = radians(angulo + 180); // converte angulo
  PVector origem = new PVector(width/2, height); // parte de baixo
  PVector centroAlvo = new PVector(
    origem.x + cos(anguloRad) * distanciaMapeada,
    origem.y + sin(anguloRad) * distanciaMapeada
  );
  // move suavemente
  centroSuavizado.lerp(centroAlvo, 0.1);
  
  // atualiza particulas
  for (int i = 0; i < numParticulas; i++) {
    particulas[i].atualizar(centroSuavizado);
  }
  
  // verifica colisoes
  verificarColisoes();
  
  // desenha particulas
  for (Particula p : particulas) {
    p.desenhar();
  }

  // desenha o alvo
  desenharAlvo(centroSuavizado.x, centroSuavizado.y);
  
  // muda a musica conforme a distancia
  boolean perto = distanciaLaser < 50; // perto ou longe
  println(distanciaLaser);
  if (perto) {
    if (volumeSom1 < 1) volumeSom1 += 0.01;
} else {
    if (volumeSom1 > 0) volumeSom1 -= 0.01;
}
  // aplica os volumes
  som1.amp(volumeSom1);
  //
  println(volumeSom1);
}

// recebe dados do arduino
void serialEvent(Serial p) {
  
  try {
    String dados = p.readStringUntil('\n').trim();
    if (dados != null) {
      String[] valores = split(dados, ',');
      if (valores.length == 3) {
        // ultrassom, laser, angulo
        distanciaUltrassonica = int(float(valores[0]));
        distanciaLaser = int(float(valores[1]));
        angulo = int(valores[2]);
      }
    }
  } catch (Exception e) {
    // ignora erros
  }
}

// evita que as particulas se sobreponham
void verificarColisoes() {
  for (int i = 0; i < numParticulas; i++) {
    for (int j = i+1; j < numParticulas; j++) {
      PVector diferenca = PVector.sub(particulas[i].pos, particulas[j].pos);
      float distancia = diferenca.mag();
      float distMin = raioColisao + particulas[i].tamanho/2 + particulas[j].tamanho/2;
      
      if (distancia < distMin && distancia > 0) {
        float forca = (distMin - distancia) / distancia * forcaColisao;
        diferenca.normalize();
        diferenca.mult(forca);
        particulas[i].pos.add(diferenca);
        particulas[j].pos.sub(diferenca);
      }
    }
  }
}

// onda que aparece com o som
class Onda {
  float x, y;          // posicao
  float raio;        // tamanho atual
  float raioMaximo;     // tamanho maximo
  float velocidade;         // velocidade
  float forca;      // força
  boolean ativa;      // se está ativa
  float cor;           // cor
  
  Onda(float x, float y, float forca, float cor) {
    this.x = x;
    this.y = y;
    this.raio = 0;
    this.raioMaximo = raioMaximoOnda;
    this.velocidade = velocidadeOnda;
    this.forca = forca * forcaOnda;
    this.cor = cor;
    this.ativa = true;
  }
  
  void atualizar() {
    if (ativa) {
      raio += velocidade;
      if (raio > raioMaximo) {
        ativa = false;
      }
    }
  }
  
  boolean terminada() {
    return !ativa;
  }

  boolean contem(float px, float py) {
    return dist(px, py, x, y) <= raio + 50 && dist(px, py, x, y) >= raio - 50;
  }

  float getForca(float px, float py) {
    float distOnda = abs(dist(px, py, x, y) - raio);
    return max(0, 1 - distOnda / 75) * forca;
  }

  color getCor() {
    return cores[int(random(cores.length))];
  }
}

// cada particula do sistema
class Particula {
  PVector pos, vel, acc, posInicial;  // posicao, velocidade, etc
  float velMax = 3.5;            // velocidade maxima
  float tamanhoBase;                  // tamanho normal
  float tamanho;              // tamanho atual
  color corAtual, corAlvo; // cores

  Particula(float x, float y) {
    pos = new PVector(x, y);
    posInicial = new PVector(x, y);  // posicao inicial
    vel = new PVector(random(-1, 1), random(-1, 1)); // velocidade aleatoria
    acc = new PVector(0, 0);
    tamanhoBase = random(1, 3);      // tamanho aleatorio
    tamanho = tamanhoBase;
    corAtual = corAtracao;  // começa com cor normal
    corAlvo = corAtracao;
  }

  void atualizar(PVector alvo) {
    acc.mult(0); // reseta

    // movimento com ruido
    float ruido = noise(pos.x / escalaRuido, pos.y / escalaRuido, frameCount / 100.0);
    float ang = ruido * TWO_PI * forcaRuido;
    acc.add(new PVector(cos(ang), sin(ang)));

    PVector dir = PVector.sub(alvo, pos);
    float dist = dir.mag();

    if (dist < raioAtracao) {
      // muda tamanho conforme distancia
      float fator = map(dist, 0, raioAtracao, tamanhoMaximo, 1.0);
      tamanho = tamanhoBase * fator;
      dir.normalize();

      if (tempoRepulsao > 0) {
        // se estiver repelindo
        float forca = forcaRepulsao * (raioAtracao - dist) / raioAtracao;
        dir.mult(-forca);
        corAlvo = corRepulsao;
      } else {
        // atração normal
        float atracao = (dist < distanciaMinima) ? atracaoMaxima
                              : lerp(atracaoBase, atracaoMaxima, 1 - (dist - distanciaMinima) / (raioAtracao - distanciaMinima));
        dir.mult(atracao * (raioAtracao - dist) / raioAtracao);
        corAlvo = corAtracao;
      }

      acc.add(dir);
    } else {
      // comportamento normal
      corAlvo = corAtracao;
      tamanho = tamanhoBase;
    }

    // efeito das ondas
    for (Onda o : ondas) {
      if (o.ativa && o.contem(pos.x, pos.y)) {
        float efeito = o.getForca(pos.x, pos.y);
        corAlvo = lerpColor(corAlvo, o.getCor(), efeito);
      }
    }
    // muda cor suavemente
    corAtual = lerpColor(corAtual, corAlvo, velocidadeMudancaCor);

    // volta para posicao inicial devagar
    PVector paraCasa = PVector.sub(posInicial, pos).mult(0.005);
    acc.add(paraCasa);

    // fisica basica
    vel.add(acc);
    vel.limit(velMax);
    pos.add(vel);

    // bate nas bordas
    if (pos.x < 0 || pos.x > width) vel.x *= -0.5;
    if (pos.y < 0 || pos.y > height) vel.y *= -0.5;
    pos.x = constrain(pos.x, 0, width);
    pos.y = constrain(pos.y, 0, height);
  }

  void desenhar() {
    noStroke();
    // brilho
    fill(corAtual);
    ellipse(pos.x, pos.y, tamanho * 3, tamanho * 3);
    // particula
    fill(corAtual);
    ellipse(pos.x, pos.y, tamanho, tamanho);
  }
}

// desenha o alvo
void desenharAlvo(float x, float y) {
  // circulos
  for (int r = 30; r < raioAtracao; r += 30) {
    noFill();
    stroke(0, random(150), random(150), map(r, 30, raioAtracao, random(150), 10));
    strokeWeight(1.5);
    ellipse(x, y, r * 2, r * 2);
  }

  // centro com gradiente
  for (int d = 30; d > 0; d -= 5) {
    fill(0, random(150), random(150), map(d, 30, 0, random(150), random(255)));
    noStroke();
    ellipse(x, y, d, d);
  }

  // centro branco
  fill(360);
  ellipse(x, y, 8, 8);
}
