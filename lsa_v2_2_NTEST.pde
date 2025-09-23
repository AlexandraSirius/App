import controlP5.*;      // библиотека для GUI-элементов (кнопки, списки, поля)
import processing.serial.*; // библиотека для работы с Serial (COM-порт)

ControlP5 cp5;           // главный объект ControlP5, через него создаются все контролы
Serial port;             // объект Serial для подключения и отправки/приёма данных

// --- Основные меню ---
ScrollableList mainMenu, midiSubList, netModeList; 
// главные выпадающие списки: главное меню, подменю MIDI, выбор сетевого режима
DropdownList rtpSelect, oscSelect; 
// выпадающие для выбора сохранённых RTP и OSC конфигураций

ColorWheel picker1, picker2, picker3, picker4; 
// четыре цветовых колеса (например, для настройки цвета квадратов)

Textfield[][] midiFields = new Textfield[7][3]; 
// поля ввода для строк "MIDI MIDI" (всего 7 строк × 3 колонки)
Textfield[][] midiInline = new Textfield[3][3]; 
// маленькие поля ввода, которые стоят ПО МЕЖДУ 3×3 выпадающими списками MIDI (по 3 на строку)

ScrollableList[] mscList = new ScrollableList[4]; 
// отдельные списки (например, для выбора MSC-сообщений), всего 4

Textfield[] rtpMsgField = new Textfield[6]; 
// поля для ввода 6 RTP-сообщений
Textfield oscField; 
// поле для ввода OSC-сообщения

// --- Сетевые поля ---
Textfield ipBox, portBox, ipOut1, ipOut2, portOut, netOscMsg; 
// ipBox/portBox – ввод IP и порта для входа
// ipOut1, ipOut2, portOut – для адреса и порта выхода
// netOscMsg – поле для OSC-сообщения

Button sendButton;       
// кнопка отправки (send)

String[] rtpSaved = new String[6]; 
String[] oscSaved = new String[6]; 
// массивы для хранения сохранённых RTP/OSC строк (по 6 штук)

ScrollableList[][] midiLeft = new ScrollableList[3][3]; 
// 3×3 выпадающих списков слева (верхняя таблица MIDI)

// НОВОЕ: по одному выпадающему для каждого нижнего прямоугольника (0..7)
ScrollableList[] rectDrop = new ScrollableList[4];

boolean deviceConnected = false; 
// флаг: есть ли подключённое устройство по Serial
String receivedData = ""; 
// буфер для принятой по Serial строки

int startTimer;          
int scanInterval = 100;  
// переменные для таймера авто-сканирования портов (каждые 100 мс)
int currentPortIndex = 0; 
// индекс текущего COM-порта при переборе
int midiLeftActiveRow = -1; 
// какая строка у midiLeft активна (-1 = никакая)

Button testButton;       
// тестовая кнопка (для отладки)
String[] testResults = {}; 
boolean showTestResults = false; 
// массив с результатами тестов + флаг, показывать ли их на экране

// --- Режимы интерфейса ---
boolean colorMode = false;  
boolean midiMode = false;   
boolean networkMode = false;
boolean oscMode = false;    

// параметры для рисования 4 квадратов снизу (размер, позиции по X и Y)
int squareSize = 100;      
int numSquares = 4;        
int squareY;               
float squareSpacing;       
float[] squareX = new float[numSquares]; 

int rtpIndex = 0, oscIndex = 0; 
// текущие индексы выбранных RTP и OSC конфигураций

void settings() {
  size(800, 600);
}

// =================== MIDI: «лестница» только для верхней 3×3 ===================
void enforceSingleOpenMidiList() {
  ScrollableList openOne = null;
  int openRow = -1; // 0..2
  int openCol = -1; // 0..2

  // 1) Ищем единственный открытый список только в верхней 3x3 (midiLeft)
  for (int c = 0; c < 3; c++) {
    for (int r = 0; r < 3; r++) {
      ScrollableList sl = (midiLeft[c][r] != null) ? midiLeft[c][r] : null;
      if (sl != null && sl.isOpen()) {
        if (openOne == null) {
          openOne = sl;
          openCol = c;
          openRow = r;
        } else {
          sl.close();
        }
      }
    }
  }

  // 2) База: всё показать (ничего не открыто — всё видно)
  for (int c = 0; c < 3; c++) {
    for (int r = 0; r < 3; r++) {
      if (midiLeft[c][r] != null) midiLeft[c][r].show();
    }
  }
  for (int r = 0; r < 3; r++) {
    for (int k = 0; k < 3; k++) {
      if (midiInline[r][k] != null) midiInline[r][k].show();
    }
  }

  // 3) «Лесенка»: прячем ТОЛЬКО элементы ниже в том же столбце верхней сетки
  if (openOne != null) {
    for (int r = openRow + 1; r < 3; r++) {
      if (midiLeft[openCol][r] != null) midiLeft[openCol][r].hide();
    }
    // Пересчитать видимость inline-полей построчно
    for (int row = 0; row < 3; row++) {
      boolean rowVisible = false;
      for (int col = 0; col < 3; col++) {
        if (midiLeft[col][row] != null && midiLeft[col][row].isVisible()) {
          rowVisible = true; break;
        }
      }
      for (int k = 0; k < 3; k++) {
        if (midiInline[row][k] != null) {
          if (rowVisible) midiInline[row][k].show();
          else           midiInline[row][k].hide();
        }
      }
    }
  }
}

void setup() {
  cp5 = new ControlP5(this);
  cp5.setFont(createFont("Arial", 16));

  for (int i = 0; i < 6; i++) {
    oscSaved[i] = "";
    rtpSaved[i] = "";
  }

  squareSpacing = (width - numSquares * squareSize) / (numSquares + 1);
  squareY = height - squareSize - 70;
  for (int i = 0; i < numSquares; i++) {
    squareX[i] = squareSpacing + i * (squareSize + squareSpacing);
  }

  // --- Главное меню ---
  mainMenu = cp5.addScrollableList("mainMenu")
    .setLabel("Main Menu").setPosition(60, 60).setSize(180, 120)
    .setBarHeight(30).setItemHeight(30).setType(ControlP5.DROPDOWN).setOpen(false);
  mainMenu.addItem("COLOR", 0);
  mainMenu.addItem("MIDI", 1);
  mainMenu.addItem("NETWORK", 2);
  mainMenu.addItem("OSC", 3);
  mainMenu.bringToFront();

  // --- Подменю MIDI ---
  midiSubList = cp5.addScrollableList("midiSubMenu")
    .setLabel("MIDI Mode").setPosition(260, 60).setSize(120, 90)
    .setBarHeight(30).setItemHeight(30).setType(ControlP5.DROPDOWN)
    .setOpen(false).hide();
  midiSubList.addItem("MIDI", 0);
  midiSubList.addItem("MSC", 1);
  midiSubList.addItem("SYSEX MIDI", 2);

  // --- Цветовые колёса (цветовой режим) ---
  int circleSize = 180;
  int spacing = 20;
  int startX = (width - (4 * circleSize +3  * spacing)) / 2-10;
  int yPos = 180;

  picker1 = cp5.addColorWheel("p1").setPosition(startX + 0 * (circleSize + spacing), yPos).setLabel("").hide();
  picker2 = cp5.addColorWheel("p2").setPosition(startX + 1 * (circleSize + spacing), yPos).setLabel("").hide();
  picker3 = cp5.addColorWheel("p3").setPosition(startX + 2 * (circleSize + spacing), yPos).setLabel("").hide();
  picker4 = cp5.addColorWheel("p4").setPosition(startX + 3 * (circleSize + spacing), yPos).setLabel("").hide();

  // --- Верхняя 3×3 сетка MIDI ---
  int fieldW = 40;
  int fieldH = 30;
  int centerX = width / 2;
  int centerY = height / 2;
  int fieldGapX = fieldW;  // чтобы влезли inline
  int fieldGapY = 12;
  int totalWidth = 3 * fieldW + 2 * fieldGapX;
  int totalHeight = 3 * fieldH + 2 * fieldGapY;
  int gridShiftLeft = 20;                     // сдвиг влево как в исходнике
  int startX_left   = centerX - totalWidth / 2 - gridShiftLeft;
  int startY_left   = centerY - totalHeight / 2;

  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      int x = startX_left + i * (fieldW + fieldGapX);
      int y = startY_left + j * (fieldH + fieldGapY);

      midiLeft[i][j] = cp5.addScrollableList("midi_left_" + i + "_" + j)
        .setPosition(x, y)
        .setSize(fieldW, 120)   // ширина — как у msc, высота раскрытия — 120
        .setBarHeight(30)
        .setItemHeight(25)
        .setLabel("")
        .hide(); // по умолчанию скрыт

      // Заполняем числами от 0 до 7
      for (int val = 0; val <= 7; val++) midiLeft[i][j].addItem(str(val), val);

      midiLeft[i][j].setValue(0);  // по умолчанию выбран «0»
      midiLeft[i][j].close();      // и сразу закрыт
    }
  }

  // --- Inline поля (между колонками 3×3) ---
  int rows = 3;
  int cols = 3;
  int inputW = int(min(fieldW, fieldGapX) * 0.7);
  int inputH = fieldH;
  int inputOffsetX = (fieldGapX - inputW) / 2;
  int inputOffsetY = 0;

  for (int row = 0; row < rows; row++) {
    int y = startY_left + row * (fieldH + fieldGapY);
    int x0 = startX_left + 0 * (fieldW + fieldGapX);
    int x1 = startX_left + 1 * (fieldW + fieldGapX);
    int x2 = startX_left + 2 * (fieldW + fieldGapX);

    // между колонками 0 и 1
    midiInline[row][0] = cp5.addTextfield("midi_inline_" + row + "_0")
      .setPosition(x0 + fieldW + inputOffsetX, y + inputOffsetY)
      .setSize(inputW, inputH)
      .setAutoClear(false)
      .setCaptionLabel("")
      .hide();

    // между колонками 1 и 2
    midiInline[row][1] = cp5.addTextfield("midi_inline_" + row + "_1")
      .setPosition(x1 + fieldW + inputOffsetX, y + inputOffsetY)
      .setSize(inputW, inputH)
      .setAutoClear(false)
      .setCaptionLabel("")
      .hide();

    // правый «боковой» за 3-й колонкой
    midiInline[row][2] = cp5.addTextfield("midi_inline_" + row + "_2")
      .setPosition(x2 + fieldW + inputOffsetX, y + inputOffsetY)
      .setSize(inputW, inputH)
      .setAutoClear(false)
      .setCaptionLabel("")
      .hide();
  }

  // --- Поля возле нижних квадратов (строки 3..6) ---
  int fieldGap = 5;
  for (int t = 0; t < 4; t++) {
    int fieldX = int(squareX[t]);
    int startYf = int(squareY);
  
    for (int j = 0; j < 1; j++) {                // << ОСТАВЛЯЕМ только верхнее поле
      int y = startYf + j * (fieldH + fieldGap);
      midiFields[t + 3][j] = cp5.addTextfield("midi" + (t + 3) + "_" + j)
        .setPosition(fieldX, y)
        .setSize(fieldW, fieldH)
        .setAutoClear(false)
        .setLabel("")
        .hide();
    }
  }


  // === НОВОЕ: по одному выпадающему справа от каждого квадрата (уровень первого поля) ===
  int ddW = 40;     // ширина бара
  int ddBarH = 30;
  int ddItemH = 25;
  int ddOffsetX = 6; // небольшой отступ от правой границы квадрата влево

  for (int t = 0; t < 4; t++) {
    int rightEdge = int(squareX[t] + squareSize);
    int ddX = rightEdge - ddOffsetX - ddW;   // у правого края квадрата
    int ddY = int(squareY);                  // напротив первого поля (j=0)
    rectDrop[t] = cp5.addScrollableList("rect_drop_" + t)
      .setType(ControlP5.DROPDOWN)
      .setPosition(ddX, ddY)
      .setSize(ddW, 120)
      .setBarHeight(ddBarH)
      .setItemHeight(ddItemH)
      .setLabel("")
      .hide();
    for (int v = 0; v <= 7; v++) rectDrop[t].addItem(str(v), v);
    rectDrop[t].setValue(0).close();
  }

  // --- Селекторы RTP/OSC, сеть и пр. из исходника (оставляем как было) ---
  for (int t = 0; t < 6; t++) {
    final int idx = t;
    rtpMsgField[t] = cp5.addTextfield("rtpMsg" + t)
      .setPosition(500, 60).setSize(200, 30)
      .setAutoClear(false).setLabel("").hide();

    // Сохранение по потере фокуса
    rtpMsgField[t].addCallback(new CallbackListener() {
      public void controlEvent(CallbackEvent event) {
        if (event.getAction() == ControlP5.ACTION_LEAVE) {
          saveRTP(idx);
        }
      }
    });
  }

  rtpSelect = cp5.addDropdownList("rtpSelect")
    .setPosition(400, 60).setSize(80, 140)
    .setBarHeight(30).setItemHeight(30)
    .setLabel("Target").setOpen(false).hide();

  rtpSelect.addItem("—", -1);
  for (int t = 1; t <= 6; t++) rtpSelect.addItem(str(t), t);
  rtpSelect.setBroadcast(false).setValue(-1).setBroadcast(true);

  rtpSelect.getCaptionLabel().align(ControlP5.CENTER, ControlP5.CENTER);
  rtpSelect.getCaptionLabel().setPaddingX(0);
  rtpSelect.getValueLabel().align(ControlP5.CENTER, ControlP5.CENTER);
  rtpSelect.setBroadcast(false).setValue(1).setBroadcast(true);

  oscField = cp5.addTextfield("oscField")
    .setPosition(360, 60).setSize(200, 30)
    .setAutoClear(false).setLabel("OSC Message").hide();

  oscSelect = cp5.addDropdownList("oscSelect")
    .setPosition(260, 60).setSize(80, 140)
    .setBarHeight(30).setItemHeight(30)
    .setLabel("Element").setOpen(false).hide();
  oscSelect.addItem("—", -1);
  for (int t = 1; t <= 6; t++) oscSelect.addItem(str(t), t);
  oscSelect.setBroadcast(false).setValue(-1).setBroadcast(true);

  ipBox = cp5.addTextfield("ipBox").setPosition(60, 180).setSize(150, 30).setLabel("IP").hide();
  portBox = cp5.addTextfield("portBox").setPosition(220, 180).setSize(150, 30).setLabel("Port").hide();
  ipOut1 = cp5.addTextfield("ipOut1").setPosition(60, 230).setSize(150, 30).setLabel("Out 1").hide();
  ipOut2 = cp5.addTextfield("ipOut2").setPosition(220, 230).setSize(150, 30).setLabel("Out 2").hide();
  portOut = cp5.addTextfield("portOut").setPosition(60, 280).setSize(150, 30).setLabel("Port Out").hide();
  netOscMsg = cp5.addTextfield("oscMsgNet").setPosition(220, 280).setSize(150, 30).setLabel("PASSCODE").hide();

  // --- Кнопки ---
  //sendButton = cp5.addButton("send").setPosition(700, 520).setSize(80, 30).setLabel("Send");
  sendButton = cp5.addButton("send").setPosition(width - 100, 20).setSize(80, 30).setLabel("Send");
  sendButton.setLock(true);
  int sendActive = color(0, 160, 0);   // зелёный активный
  int sendInactive = color(120);       // серый неактивный
  sendButton.setColorBackground(sendInactive);
  sendButton.setColorForeground(sendInactive);

  testButton = cp5.addButton("testNetwork")
    .setLabel("TEST")
    .setPosition(390, 130)
    .setSize(80, 30)
    .hide();  

  startAutomaticPortScan();
}

void draw() {
  background(125);
  drawModeIndicator();

  if (deviceConnected && port == null) {
    onDeviceDisconnected();
  }
  if (!deviceConnected) {
    int elapsed = millis() - startTimer;
    if (elapsed > scanInterval) {
      connectToNextPort();
      startTimer = millis();
    }
    // ДЕРЖИМ кнопку залоченной, если устройство не подключено
    if (sendButton != null && !sendButton.isLock()) sendButton.setLock(true);
  } else {
    // РАЗЛОЧИВАЕМ только когда реально подключены
    if (sendButton != null && sendButton.isLock()) sendButton.setLock(false);
  }

  // Графика (круг+квадраты) как в исходнике при MIDI/OSC
  if (midiMode || oscMode) {
    fill(0);
    ellipse(width/2, height/2, 150, 150);

    for (int i = 0; i < numSquares; i++) {
      rect(squareX[i], squareY, squareSize, squareSize);
    }

    fill(255);
    textAlign(CENTER, CENTER);
    textSize(20);
    text("1", width/2 - 90, height/2);
    text("2", width/2 + 90, height/2);
    for (int i = 0; i < numSquares; i++) {
      float labelX = squareX[i] - 10;
      float labelY = squareY + squareSize / 2;
      textAlign(RIGHT, CENTER);
      text(str(3 + i), labelX, labelY);
    }
  }

  if (networkMode && showTestResults) {
    int resultX = 400;
    int resultY = 190;

    fill(255, 240);
    stroke(0);
    rect(resultX - 10, resultY - 10, 300, max(40, testResults.length * 20 + 30));

    fill(0);
    textSize(14);
    textAlign(LEFT, TOP);
    text("Ответ от устройства:", resultX, resultY);

    for (int i = 0; i < testResults.length; i++) {
      text("- " + testResults[i], resultX, resultY + 20 + i * 20);
    }
  }

  if (colorMode) {
    picker1.show(); picker2.show(); picker3.show(); picker4.show();
  } else {
    picker1.hide(); picker2.hide(); picker3.hide(); picker4.hide();
  }

  if (midiMode) {
    int sub = 0;
    if (midiSubList != null) {
      // В ControlP5 getValue() — float; 0 = MIDI, 1 = MSC, 2 = RTP
      sub = (int)midiSubList.getValue();
    }
    if (sub == 0) { // мы на странице "MIDI"
      enforceSingleOpenMidiList();
    }
  }
}

void serialEvent(Serial p) {
  receivedData = p.readStringUntil('\n');
  if (receivedData != null) {
    receivedData = receivedData.trim();
    println("Received: " + receivedData);

    if (receivedData.equals("box")) {
      deviceConnected = true;
      if (sendButton != null) sendButton.setLock(false);
      println("Device connected!");
    } else if (receivedData.startsWith("reply:")) {
      testResults = append(testResults, receivedData.substring(6).trim());
      println("Добавлен ответ: " + receivedData);
    } else {
      println("Unknown response: " + receivedData);
    }
  } else {
    println("No data received or connection issue.");
  }
}

void startAutomaticPortScan() {
  startTimer = millis();
  currentPortIndex = 0;
  deviceConnected = false;
}

void connectToNextPort() {
  String[] ports = Serial.list();

  if (ports.length == 0) {
    println("Нет доступных COM-портов. Подключи устройство.");
    return;
  }

  if (port != null) {
    port.stop();
    port = null;
  }

  try {
    println("Пробуем порт: " + ports[currentPortIndex]);
    port = new Serial(this, ports[currentPortIndex], 9600);
    port.bufferUntil('\n');
    safeWrite("who\n");
    currentPortIndex = (currentPortIndex + 1) % ports.length;
  }
  catch (Exception e) {
    println("Ошибка открытия порта: " + e.getMessage());
    currentPortIndex = (currentPortIndex + 1) % ports.length;
  }
}

void drawModeIndicator() {
  String activeMode = "";
  if (colorMode) activeMode = "ACTIVE MODE: COLOR";
  else if (midiMode) activeMode = "ACTIVE MODE: MIDI";
  else if (networkMode) activeMode = "ACTIVE MODE: NETWORK";
  else if (oscMode) activeMode = "ACTIVE MODE: OSC";

  fill(255);
  textSize(16);
  textAlign(LEFT, TOP);
  text(activeMode, 60, 30);
}

void controlEvent(ControlEvent event) {
  if (event.isFrom(rtpSelect)) {
    int prevIndex = rtpIndex;
    Float val = rtpSelect.getValue();

    if (val != null && val >= 1 && val <= 6) {
      int newIndex = val.intValue() - 1;

      // Сохраняем старое
      saveRTP(prevIndex);

      rtpIndex = newIndex;

      if (rtpMsgField[rtpIndex] != null) {
        rtpMsgField[rtpIndex].setText(rtpSaved[rtpIndex] != null ? rtpSaved[rtpIndex] : "");
        rtpMsgField[rtpIndex].show().bringToFront();
      }
    } else {
      // Если выбран "—"
      saveRTP(prevIndex);
      if (rtpMsgField[prevIndex] != null) {
        rtpMsgField[prevIndex].setText(rtpSaved[prevIndex] != null ? rtpSaved[prevIndex] : "");
        rtpMsgField[prevIndex].hide();
      }
      rtpIndex = 0;
    }

    rtpSelect.close();
    rtpSelect.bringToFront();
    mainMenu.bringToFront();
  }

  if (event.isFrom(mainMenu)) {
    int selection = (int) event.getValue();
    colorMode = midiMode = networkMode = oscMode = false;
    midiSubList.hide();
    hideAll();
    mainMenu.close();
    mainMenu.bringToFront();

    switch (selection) {
    case 0:
      colorMode = true;
      break;

    case 1:
      midiMode = true;
      midiSubList.show().bringToFront();
      mainMenu.bringToFront();
      midiSubList.setBroadcast(false);
      midiSubList.setValue(0);
      midiSubList.setBroadcast(true);

      // 1) верхняя 3×3
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          if (midiLeft[i][j] != null) {
            midiLeft[i][j].show().bringToFront();
            midiLeft[i][j].close(); // стартуем закрытыми, как и поля
          }
        }
      }
      // 2) текстовые поля у квадратов 3–6
      for (int i = 3; i < 7; i++) {
        for (int j = 0; j < 3; j++) {
          if (midiFields[i][j] != null) {
            midiFields[i][j].show();
          }
        }
      }
      // 3) НОВОЕ — показать правые выпадающие (по одному на квадрат)
      for (int t = 0; t < 4; t++) {
        if (rectDrop[t] != null) rectDrop[t].show().bringToFront();
      }
      break;

    case 2:
      networkMode = true;
      showNetwork();
      mainMenu.bringToFront();
      break;

    case 3:
      oscMode = true;
      oscSelect.show().bringToFront();
      mainMenu.bringToFront();
      Float val = oscSelect.getValue();
      if (val != null && val >= 1 && val <= 6) {
        oscIndex = val.intValue() - 1;
        if (oscField != null) {
          oscField.setText(oscSaved[oscIndex] != null ? oscSaved[oscIndex] : "");
          oscField.show().bringToFront();
        }
      } else {
        oscIndex = 0;
        if (oscField != null) {
          oscField.setText("");
          oscField.hide();
        }
      }
      break;
    }
  }

  if (event.isFrom(midiSubList)) {
    hideAll();
    int sub = (int) midiSubList.getValue();
    midiSubList.close();
    midiSubList.bringToFront();
    mainMenu.bringToFront();

    if (sub == 0) {
      // Показать 3×3 выпадающих списков слева (midiLeft)
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          if (midiLeft[i][j] != null) midiLeft[i][j].show().bringToFront();
        }
      }
      // Показать межколоночные поля (и правое боковое)
      for (int row = 0; row < 3; row++) {
        for (int k = 0; k < 3; k++) {
          if (midiInline[row][k] != null) midiInline[row][k].show().bringToFront();
        }
      }
      // Показать текстовые поля в квадратах 3–6
      for (int i = 3; i < 7; i++) {
        for (int j = 0; j < 3; j++) {
          if (midiFields[i][j] != null) midiFields[i][j].show();
        }
      }
      // НОВОЕ — показать правые выпадающие (по одному на квадрат)
      for (int t = 0; t < 4; t++) {
        if (rectDrop[t] != null) rectDrop[t].show().bringToFront();
      }
    } 
    else if (sub == 1) {
      for (ScrollableList s : mscList) {
        if (s != null) s.show();
      }
    } 
    else if (sub == 2) {
      saveRTP(rtpIndex);
      rtpSelect.show().bringToFront();
      mainMenu.bringToFront();

      Float val = rtpSelect.getValue();
      if (val != null && val >= 1 && val <= 6) {
        rtpIndex = val.intValue() - 1;
      } else {
        rtpIndex = 0;  // по умолчанию
        rtpSelect.setValue(1);  // установить если ничего не выбрано
      }

      for (int i = 0; i < 6; i++) {
        if (rtpMsgField[i] != null) rtpMsgField[i].hide();
      }
      if (rtpMsgField[rtpIndex] != null) {
        rtpMsgField[rtpIndex].setText(rtpSaved[rtpIndex] != null ? rtpSaved[rtpIndex] : "");
        rtpMsgField[rtpIndex].show().bringToFront();
      }
    }
  }

  if (event.isFrom(oscSelect)) {
    int prevOscIndex = oscIndex;
    Float val = oscSelect.getValue();

    if (val != null && val >= 1 && val <= 6) {
      int newIndex = val.intValue() - 1;

      // Сохраняем только если индекс изменился
      if (newIndex != prevOscIndex) {
        if (oscField != null) {
          oscSaved[prevOscIndex] = oscField.getText();
        }
        oscIndex = newIndex;
      }

      if (oscField != null) {
        oscField.setText(oscSaved[oscIndex] != null ? oscSaved[oscIndex] : "");
        oscField.show().bringToFront();
      }
    } else {
      // Обработка выбора "—"
      if (oscField != null) {
        oscSaved[prevOscIndex] = oscField.getText();
        oscField.setText("");
        oscField.hide();
      }
      oscIndex = 0;
    }

    oscSelect.close();
    oscSelect.bringToFront();
    mainMenu.bringToFront();
  }

  if (event.isController() && event.getController().getName().equals("send")) {
    if (!deviceConnected) return; // защита от клика без устройства
    sendParameters();
  }
  if (event.isController() && event.getController().getName().equals("testNetwork")) {
    safeWrite("test\n"); 
    testResults = new String[0];  // очистка старого списка
    showTestResults = true;
  }
}

void hideAll() {
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      if (midiLeft[i][j] != null) midiLeft[i][j].hide();
    }
  }
  for (int row = 0; row < 3; row++) {
    for (int k = 0; k < 3; k++) {
      if (midiInline[row][k] != null) midiInline[row][k].hide();
    }
  }

  for (Textfield[] group : midiFields) {
    for (Textfield tf : group) {
      if (tf != null) tf.hide();
    }
  }
  // НОВОЕ — прячем правые выпадающие по одному на квадрат
  for (int t = 0; t < 4; t++) {
    if (rectDrop[t] != null) rectDrop[t].hide();
  }

  for (ScrollableList s : mscList) {
    if (s != null) s.hide();
  }

  for (Textfield f : rtpMsgField) {
    if (f != null) f.hide();
  }
  if (rtpSelect != null) rtpSelect.hide();
  if (oscSelect != null) oscSelect.hide();
  if (oscField != null) oscField.hide();
  if (ipBox != null) ipBox.hide();
  if (portBox != null) portBox.hide();
  if (ipOut1 != null) ipOut1.hide();
  if (ipOut2 != null) ipOut2.hide();
  if (portOut != null) portOut.hide();
  if (netOscMsg != null) netOscMsg.hide();
  if (testButton != null) testButton.hide();
}

void onDeviceDisconnected() {
  deviceConnected = false;
  // аккуратно закрыть порт
  if (port != null) {
    try { port.stop(); } catch (Exception e) {}
    port = null;
  }
  // залочить кнопку и заново запустить автопоиск
  if (sendButton != null) sendButton.setLock(true);
  startAutomaticPortScan(); // включает цикл сканирования в draw()
}

boolean safeWrite(String msg) {
  try {
    if (port != null) {
      port.write(msg);
      return true;
    }
  } catch (Exception e) {
    println("Serial write failed: " + e.getMessage());
    onDeviceDisconnected(); // сразу в поиск
  }
  return false;
}

void showNetwork() {
  if (ipBox != null) ipBox.show();
  if (portBox != null) portBox.show();
  if (ipOut1 != null) ipOut1.show();
  if (ipOut2 != null) ipOut2.show();
  if (portOut != null) portOut.show();
  if (netOscMsg != null) netOscMsg.show();
  if (testButton != null) testButton.show();
}

void showRTPField(int idx) {
  if (rtpMsgField == null) return;

  // Скрываем все поля
  for (int i = 0; i < 6; i++) {
    if (rtpMsgField[i] != null) rtpMsgField[i].hide();
  }

  // Показываем только нужное поле
  if (idx >= 0 && idx < 6 && rtpMsgField[idx] != null) {
    // Всегда устанавливаем сохраненное значение
    rtpMsgField[idx].setText(rtpSaved[idx] != null ? rtpSaved[idx] : "");
    rtpMsgField[idx].show().bringToFront();
  }
}

void saveRTP(int idx) {
  if (idx >= 0 && idx < 6 && rtpMsgField[idx] != null) {
    // Сохраняем только если значение изменилось
    String currentValue = rtpMsgField[idx].getText();
    if (!currentValue.equals(rtpSaved[idx])) {
      rtpSaved[idx] = currentValue;
      println("Saved RTP " + idx + ": " + currentValue);
    }
  }
}

void sendParameters() {
  if (colorMode) {
    safeWrite("eewr\n");
  }

  if (midiMode) {
    int midiSub = (int) midiSubList.getValue();

    if (midiSub == 0) {
      // === ДОБАВЛЕНО: отправка полей между списками (midiInline) построчно
      // Формат: "midiInline0,a,b,c", "midiInline1,a,b,c", "midiInline2,a,b,c"
      for (int row = 0; row < 3; row++) {
        StringBuilder sbI = new StringBuilder("midiInline" + row);
        for (int k = 0; k < 3; k++) {
          String val = (midiInline[row][k] != null) ? midiInline[row][k].getText().trim() : "";
          if (val.isEmpty()) val = "0";  // дефолт, чтобы не отправлять пустое
          sbI.append(",").append(val);
        }
        String msgI = sbI.toString() + "\n";
        safeWrite(msgI);
        println("Sent: " + msgI.trim());
      }

      // === Старая отправка midi0..midi6 (верх и поля у квадратов) ===
  for (int i = 0; i < 7; i++) {
    StringBuilder sb = new StringBuilder("midi" + i);
    for (int j = 0; j < 3; j++) {
      Controller<?> ctrl = cp5.getController("midi_left_" + i + "_" + j);
  
      if (ctrl instanceof ScrollableList) {
        float selVal = ((ScrollableList) ctrl).getValue();
        sb.append(",").append((int) selVal);
      } else {
        String val = "0";
        if (midiFields[i][j] != null) {
          String tval = midiFields[i][j].getText();
          if (tval != null && tval.trim().length() > 0) {
            val = tval.trim();
          }
        }
        sb.append(",").append(val);
      }
    }
    String msg = sb.toString() + "\n";
    safeWrite(msg);
    println("Sent: " + msg.trim());
  }


      // === НОВОЕ: отправка правых дропдаунов у квадратов ===
      // Формат: "midiRight{3..6},val"
      for (int t = 0; t < 4; t++) {
        int v = 0;
        if (rectDrop[t] != null) {
          try { v = (int)rectDrop[t].getValue(); } catch (Exception e) {}
        }
        String msgR = "midiRight" + (t + 3) + "," + v + "\n";
        safeWrite(msgR);
        println("Sent: " + msgR.trim());
      }

    } else if (midiSub == 1) {
      for (int i = 0; i < 4; i++) {
        if (mscList[i] != null) {
          int val = (int) mscList[i].getValue();
          String msg = "midimsc" + i + "," + val + "\n";
          safeWrite(msg);
          println("Sent: " + msg.trim());
        }
      }

    } else if (midiSub == 2) {
      if (rtpSaved[rtpIndex] != null && !rtpSaved[rtpIndex].trim().equals("")) {
        String msg = "rtp" + (rtpIndex + 1) + "," + rtpSaved[rtpIndex].trim() + "\n";
        safeWrite(msg);
        println("Sent: " + msg.trim());
      }
    }
  }

  if (oscMode) {
    Float sel = (oscSelect != null) ? oscSelect.getValue() : null;
    if (sel == null || sel < 1 || sel > 6) {
      println("OSC: элемент не выбран — отправка отменена.");
      return;
    }

    int idx = sel.intValue() - 1; // если прошивка ждёт 0..5
    if (oscField != null) {
      oscSaved[idx] = oscField.getText();
    }

    String payload = (oscSaved[idx] != null) ? oscSaved[idx].trim() : "";
    if (payload.isEmpty()) {
      println("OSC: пустое сообщение — отправка отменена.");
      return;
    }

    String msg = "osc" + (idx + 1) + "/" + payload + "\n"; // (idx+1) если 1..6
    safeWrite(msg);
    println("Sent: " + msg.trim());
  }

  if (networkMode) {
    String[] netVals = {
      ipBox != null ? ipBox.getText() : "",
      portBox != null ? portBox.getText() : "",
      ipOut1 != null ? ipOut1.getText() : "",
      ipOut2 != null ? ipOut2.getText() : "",
      portOut != null ? portOut.getText() : "",
      netOscMsg != null ? netOscMsg.getText() : ""
    };

    for (int i = 0; i < netVals.length; i++) {
      if (!netVals[i].trim().equals("")) {
        String msg = "me_set" + i + "," + netVals[i].trim() + "\n";
        safeWrite(msg);
        println("Sent: " + msg.trim());
      }
    }
  }
}

void p1(int col) {
  String str = "b0," + int(red(col)) + "," + int(green(col)) + "," + int(blue(col)) + "\n";
  safeWrite(str);
  println(int(red(col)) + ":" + int(green(col)) + ":" + int(blue(col)));
}

void p2(int col) {
  String str = "b1," + int(red(col)) + "," + int(green(col)) + "," + int(blue(col)) + "\n";
  safeWrite(str);
  println(int(red(col)) + ":" + int(green(col)) + ":" + int(blue(col)));
}

void p3(int col) {
  String str = "b2," + int(red(col)) + "," + int(green(col)) + "," + int(blue(col)) + "\n";
  safeWrite(str);
  println(int(red(col)) + ":" + int(green(col)) + ":" + int(blue(col)));
}

void p4(int col) {
  String str = "b3," + int(red(col)) + "," + int(green(col)) + "," + int(blue(col)) + "\n";
  safeWrite(str);
  println(int(red(col)) + ":" + int(green(col)) + ":" + int(blue(col)));
}
