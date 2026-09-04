#pragma once

#include <QString>

namespace TrioSoftTheme {

inline QString styleSheet()
{
    // TrioSoft App Hub dark theme adapted from the website design tokens.
    // Website reference palette:
    // canvas #000000, raised #16171b/#1c1d22, ink #f2f4f8,
    // accent #0a78ee, accent-2 #6b68f5, edge rgba(255,255,255,.11).
    return QStringLiteral(R"TSQSS(
* {
    font-family: "Segoe UI Variable Text", "Segoe UI", "Inter";
    font-size: 10pt;
    color: #f2f4f8;
}

QMainWindow, QDialog, QWizard, QMessageBox {
    background: #000000;
}

QWidget#centralWidget,
QStackedWidget,
QScrollArea,
QScrollArea > QWidget > QWidget {
    background: #000000;
}

QLabel {
    background: transparent;
    color: #f2f4f8;
}

QLabel:disabled {
    color: #676b75;
}

QMenuBar {
    background: #0a0b0e;
    border-bottom: 1px solid rgba(255,255,255,28);
    padding: 3px 6px;
}

QMenuBar::item {
    background: transparent;
    border-radius: 8px;
    padding: 6px 10px;
    color: #c9ccd4;
}

QMenuBar::item:selected {
    background: rgba(255,255,255,18);
    color: #ffffff;
}

QToolBar {
    background: #0a0b0e;
    border: none;
    border-bottom: 1px solid rgba(255,255,255,28);
    spacing: 5px;
    padding: 6px 8px;
}

QToolBar QToolButton {
    background: transparent;
    border: 1px solid transparent;
    border-radius: 10px;
    padding: 6px 9px;
    margin: 1px;
    color: #c9ccd4;
}

QToolBar QToolButton:hover {
    background: rgba(255,255,255,18);
    border-color: rgba(255,255,255,24);
    color: #ffffff;
}

QToolBar QToolButton:pressed,
QToolBar QToolButton:checked {
    background: rgba(10,120,238,46);
    border-color: rgba(77,164,255,100);
    color: #ffffff;
}

QStatusBar {
    background: #0a0b0e;
    border-top: 1px solid rgba(255,255,255,24);
    color: #7b7f89;
}

QStatusBar QLabel {
    color: #8f939e;
}

QMenu {
    background: #16171b;
    border: 1px solid rgba(255,255,255,30);
    border-radius: 12px;
    padding: 6px;
}

QMenu::item {
    min-height: 24px;
    border-radius: 8px;
    padding: 6px 28px 6px 10px;
    color: #d6d9e0;
}

QMenu::item:selected {
    background: rgba(10,120,238,52);
    color: #ffffff;
}

QMenu::separator {
    height: 1px;
    background: rgba(255,255,255,22);
    margin: 5px 8px;
}

QPushButton,
QDialogButtonBox QPushButton {
    min-height: 36px;
    padding: 0 14px;
    border: 1px solid rgba(255,255,255,28);
    border-radius: 11px;
    background: #1c1d22;
    color: #f2f4f8;
    font-weight: 600;
}

QPushButton:hover,
QDialogButtonBox QPushButton:hover {
    background: #25262c;
    border-color: rgba(255,255,255,48);
}

QPushButton:pressed,
QDialogButtonBox QPushButton:pressed {
    background: #121318;
}

QPushButton:default,
QDialogButtonBox QPushButton:default {
    background: qlineargradient(x1:0,y1:0,x2:1,y2:1, stop:0 #0a78ee, stop:1 #6b68f5);
    border-color: rgba(124,166,255,120);
    color: #ffffff;
}

QPushButton:default:hover,
QDialogButtonBox QPushButton:default:hover {
    background: qlineargradient(x1:0,y1:0,x2:1,y2:1, stop:0 #2088f4, stop:1 #7976ff);
}

QPushButton:disabled {
    background: #111216;
    border-color: rgba(255,255,255,16);
    color: #60636c;
}

QLineEdit,
QTextEdit,
QPlainTextEdit,
QComboBox,
QSpinBox,
QDoubleSpinBox,
QDateEdit,
QTimeEdit,
QDateTimeEdit {
    min-height: 34px;
    background: #16171b;
    border: 1px solid rgba(255,255,255,28);
    border-radius: 10px;
    padding: 4px 9px;
    selection-background-color: #0a78ee;
    selection-color: #ffffff;
    color: #f2f4f8;
}

QTextEdit,
QPlainTextEdit {
    padding: 8px 10px;
}

QLineEdit:hover,
QTextEdit:hover,
QPlainTextEdit:hover,
QComboBox:hover,
QSpinBox:hover,
QDoubleSpinBox:hover {
    border-color: rgba(255,255,255,45);
}

QLineEdit:focus,
QTextEdit:focus,
QPlainTextEdit:focus,
QComboBox:focus,
QSpinBox:focus,
QDoubleSpinBox:focus {
    border: 1px solid #4da4ff;
    background: #191a1f;
}

QLineEdit:disabled,
QComboBox:disabled,
QSpinBox:disabled,
QDoubleSpinBox:disabled {
    color: #686b74;
    background: #111216;
}

QComboBox::drop-down {
    border: none;
    width: 26px;
}

QComboBox QAbstractItemView {
    background: #1c1d22;
    border: 1px solid rgba(255,255,255,32);
    border-radius: 10px;
    selection-background-color: rgba(10,120,238,82);
    selection-color: #ffffff;
    padding: 4px;
}

QAbstractItemView,
QListView,
QTreeView,
QTableView {
    background: #0a0b0e;
    alternate-background-color: #101116;
    border: 1px solid rgba(255,255,255,24);
    border-radius: 12px;
    color: #d9dce3;
    selection-background-color: rgba(10,120,238,82);
    selection-color: #ffffff;
    outline: 0;
}

QAbstractItemView::item {
    min-height: 28px;
    border-radius: 7px;
    padding: 3px 5px;
}

QAbstractItemView::item:hover {
    background: rgba(255,255,255,14);
}

QAbstractItemView::item:selected {
    background: rgba(10,120,238,74);
    color: #ffffff;
}

QHeaderView::section {
    background: #16171b;
    border: none;
    border-right: 1px solid rgba(255,255,255,20);
    border-bottom: 1px solid rgba(255,255,255,24);
    color: #a2a6b0;
    padding: 7px 8px;
    font-weight: 600;
}

QTabWidget::pane {
    border: 1px solid rgba(255,255,255,24);
    border-radius: 14px;
    background: #0a0b0e;
    top: -1px;
}

QTabBar::tab {
    background: transparent;
    color: #8e929c;
    border: 1px solid transparent;
    border-radius: 9px;
    padding: 7px 12px;
    margin: 2px;
}

QTabBar::tab:hover {
    background: rgba(255,255,255,16);
    color: #dfe2e8;
}

QTabBar::tab:selected {
    background: #1c1d22;
    border-color: rgba(255,255,255,28);
    color: #ffffff;
}

QGroupBox {
    margin-top: 12px;
    padding: 16px 12px 12px 12px;
    border: 1px solid rgba(255,255,255,24);
    border-radius: 14px;
    background: #0a0b0e;
    font-weight: 600;
}

QGroupBox::title {
    subcontrol-origin: margin;
    left: 12px;
    padding: 0 6px;
    color: #c7cad2;
}

QCheckBox,
QRadioButton {
    spacing: 8px;
    color: #d6d9e0;
}

QCheckBox::indicator,
QRadioButton::indicator {
    width: 17px;
    height: 17px;
    border: 1px solid rgba(255,255,255,58);
    background: #16171b;
}

QCheckBox::indicator {
    border-radius: 5px;
}

QRadioButton::indicator {
    border-radius: 9px;
}

QCheckBox::indicator:hover,
QRadioButton::indicator:hover {
    border-color: #4da4ff;
}

QCheckBox::indicator:checked,
QRadioButton::indicator:checked {
    background: #0a78ee;
    border-color: #4da4ff;
}

QProgressBar {
    min-height: 8px;
    max-height: 8px;
    border: none;
    border-radius: 4px;
    background: #1c1d22;
    color: transparent;
}

QProgressBar::chunk {
    border-radius: 4px;
    background: qlineargradient(x1:0,y1:0,x2:1,y2:0, stop:0 #0a78ee, stop:1 #6b68f5);
}

QSlider::groove:horizontal {
    height: 5px;
    border-radius: 3px;
    background: #25262c;
}

QSlider::sub-page:horizontal {
    border-radius: 3px;
    background: #0a78ee;
}

QSlider::handle:horizontal {
    width: 16px;
    margin: -6px 0;
    border-radius: 8px;
    background: #f2f4f8;
    border: 1px solid #4da4ff;
}

QScrollBar:vertical {
    width: 11px;
    margin: 2px;
    background: transparent;
}

QScrollBar:horizontal {
    height: 11px;
    margin: 2px;
    background: transparent;
}

QScrollBar::handle:vertical,
QScrollBar::handle:horizontal {
    min-height: 30px;
    min-width: 30px;
    border-radius: 5px;
    background: rgba(162,166,176,60);
}

QScrollBar::handle:vertical:hover,
QScrollBar::handle:horizontal:hover {
    background: rgba(77,164,255,120);
}

QScrollBar::add-line,
QScrollBar::sub-line,
QScrollBar::add-page,
QScrollBar::sub-page {
    background: transparent;
    border: none;
    width: 0;
    height: 0;
}

QSplitter::handle {
    background: rgba(255,255,255,18);
}

QToolTip {
    background: #1c1d22;
    color: #f2f4f8;
    border: 1px solid rgba(255,255,255,32);
    border-radius: 8px;
    padding: 6px 8px;
}

QFrame[frameShape="4"],
QFrame[frameShape="5"] {
    color: rgba(255,255,255,24);
}
)TSQSS");
}

} // namespace TrioSoftTheme
