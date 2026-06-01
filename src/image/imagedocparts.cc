// -*- mode: c++; tab-width: 4; indent-tabs-mode: t; eval: (progn (c-set-style "stroustrup") (c-set-offset 'innamespace 0)); -*-
// vi:set ts=4 sts=4 sw=4 noet :
//
// Copyright 2010-2020 wkhtmltopdf authors
//
// This file is part of wkhtmltopdf.
//
// wkhtmltopdf is free software: you can redistribute it and/or modify
// it under the terms of the GNU Lesser General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// wkhtmltopdf is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with wkhtmltopdf.  If not, see <http://www.gnu.org/licenses/>.

#include "imagecommandlineparser.hh"
#include "outputter.hh"
#include <QWebFrame>

#define STRINGIZE_(x) #x
#define STRINGIZE(x) STRINGIZE_(x)

/*!
  Output name and a short description
  \param o The outputter to output to
*/
void ImageCommandLineParser::outputManName(Outputter * o) const {
	o->beginSection("Name");
	o->paragraph("wkhtmltoimage - html to image converter");
	o->endSection();
}

/*!
  Output a short synopsis on how to call the command line program
  \param o The outputter to output to
*/
void ImageCommandLineParser::outputSynopsis(Outputter * o) const {
	o->beginSection("Usage");
	o->verbatim("wkhtmltoimage [OPTION]... <input url/file> <output image>\n");
	o->endSection();
}

/*!
  Explain what the program does
  \param o The outputter to output to
*/
void ImageCommandLineParser::outputDescripton(Outputter * o) const {
	o->beginSection("Description");
#ifdef __EXTENSIVE_WKHTMLTOPDF_QT_HACK__
	o->paragraph("Convert HTML from a URL, local file or stdin into an image. "
				 "This is a full patched-Qt build.");
#else
	o->paragraph("Convert HTML from a URL, local file or stdin into an image. "
				 "This build is not using wkhtmltopdf patched Qt.");
#endif
	o->endSection();
}


/*!
  Output contact information
  \param o The outputter to output to
*/
void ImageCommandLineParser::outputContact(Outputter * o) const {
	o->beginSection("Contact");
	o->beginParagraph();
	o->text("If you experience bugs or want to request new features please visit ");
	o->link("https://wkhtmltopdf.org/support.html");
	o->endParagraph();
	o->endSection();
}

/*!
  Output beginning of the readme
  \param o The outputter to output to
*/
void ImageCommandLineParser::outputDocStart(Outputter * o) const {
	o->beginSection("wkhtmltoimage " STRINGIZE(FULL_VERSION) " Manual");
	o->paragraph("This file documents wkhtmltoimage, a program capable of converting HTML "
				 "documents into images.");
	o->endSection();
}

/*!
  Output information on how to compile
  \param o The outputter to output to
*/
void ImageCommandLineParser::outputCompilation(Outputter * o) const {
	o->beginSection("Compilation");
	o->paragraph("It can happen that the static binary does not work for your system "
		     "for one reason or the other, in that case you might need to compile "
		     "wkhtmltoimage yourself.");
	o->endParagraph();
	o->endSection();
}

/*!
  Output information on how to install
  \param o The outputter to output to
*/
void ImageCommandLineParser::outputInstallation(Outputter * o) const {
	o->beginSection("Installation");
	o->paragraph(
		"There are several ways to install wkhtmltoimage.  You can download a "
		"already compiled binary, or you can compile wkhtmltoimage yourself. ");
	o->endSection();
}

/*!
  Output examples on how to use wkhtmltoimage
  \param o The outputter to output to
*/
void ImageCommandLineParser::outputExamples(Outputter * o) const {
	o->beginSection("Examples");
	o->paragraph("Convert a web page or local file to PNG:");
	o->verbatim("wkhtmltoimage https://example.com page.png\n"
				"wkhtmltoimage page.html page.png\n");
	o->paragraph("Choose size and format:");
	o->verbatim("wkhtmltoimage --width 1280 --height 720 --format jpg page.html page.jpg\n");
	o->paragraph("Crop around the first element matching a CSS selector:");
	o->verbatim("wkhtmltoimage --selector '#logo' https://example.com logo.png\n");
	o->paragraph("Install completion for your active shell only:");
	o->verbatim("wkhtmltoimage --install-completion\n");
	o->endSection();
}
