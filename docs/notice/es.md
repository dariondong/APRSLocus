# v1.6.156 ya está disponible: el beacon inteligente puede emitir al girar

Esta versión va de **trazas y balizas**:

- **Un tercer criterio para el beacon inteligente**: además del *temporizador* y la
  *distancia*, ahora puede **emitir cuando el rumbo cambia lo suficiente**. En
  carretera de montaña vas despacio y el umbral de distancia tarda mucho en
  alcanzarse, pero esas curvas son justo donde más importa la traza. El ángulo es
  **por nivel** (10–180°, 0 = desactivado).

- **Muestreo de la traza en vivo refinado a 1 segundo**: antes era un punto cada
  diez segundos y las curvas salían como diagonales. Los puntos **enviados de
  verdad al servidor** se marcan con pequeños rombos naranjas.

- **El campo de comentario de la estación ahora parece editable**: esa fila estaba
  en blanco y nadie sabía que se podía tocar.

Consulta las [notas de la versión](https://github.com/dariondong/APRSLocus/releases)
y el [manual](https://aprslocus.theez.top/es/manual/).
