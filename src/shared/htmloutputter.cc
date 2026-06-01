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

#include "outputter.hh"
#include <QByteArray>
#include <QTextDocument>

class HtmlOutputter: public Outputter {
private:
	FILE * fd;
	bool ordered;

	QByteArray escapedUtf8(const QString & value) const {
#if QT_VERSION >= 0x050000
		return value.toHtmlEscaped().toUtf8();
#else
		return Qt::escape(value).toUtf8();
#endif
	}

	void writeEscaped(const QString & value) {
		QByteArray data = escapedUtf8(value);
		fprintf(fd, "%s", data.constData());
	}

public:
	HtmlOutputter(FILE * _): fd(_) {
		fprintf(fd,
				"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n"
				"<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\" dir=\"ltr\">\n"
				"<head>\n"
				"  <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />\n"
				"  <title>wkhtmltopdf - Manual</title>\n"
				"  <style type=\"text/css\">\n"
				"    body {width: 70em}\n"
				"    .short {font-weight: bold; width:2em}\n"
				"    .long {font-weight: bold; width: 15em}\n"
				"    .arg {font-style: italic; width: 12em}\n"
				"    tr {vertical-align: top}\n"
				"  </style>\n"
				"</head><body>");
	}

	~HtmlOutputter() {
		fprintf(fd,"</body></html>\n");
	}

	void beginSection(const QString & name) {
		QByteArray anchor = escapedUtf8(name);
		QByteArray title = escapedUtf8(name);
		fprintf(fd, "<a name=\"%s\"><h1>%s</h1></a>\n", anchor.constData(), title.constData());
	}

	void endSection() {
	}

	void beginParagraph() {
		fprintf(fd,"<p>");
	}

	void endParagraph() {
		fprintf(fd,"</p>\n");
	}

	void text(const QString & t) {
		writeEscaped(t);
	}

	void sectionLink(const QString & s) {
		QByteArray anchor = escapedUtf8(s);
		QByteArray label = escapedUtf8(s);
		fprintf(fd, "<a href=\"#%s\">%s</a>", anchor.constData(), label.constData());
	}

	void bold(const QString & t) {
		QByteArray data = escapedUtf8(t);
		fprintf(fd, "<b>%s</b>", data.constData());
	}

	void italic(const QString & t) {
		QByteArray data = escapedUtf8(t);
		fprintf(fd, "<i>%s</i>", data.constData());
	}

	void link(const QString & t) {
		QByteArray data = escapedUtf8(t);
		fprintf(fd, "<a href=\"%s\">%s</a>", data.constData(), data.constData());
	}

	void verbatim(const QString & t) {
		QByteArray data = escapedUtf8(t);
		fprintf(fd, "<pre>%s</pre>", data.constData());
	}

	void beginList(bool o) {
		ordered = o;
		fprintf(fd, ordered?"<ol>":"<ul>");
	}

	void endList() {
		fprintf(fd, ordered?"</ol>":"</ul>");
	}

	void listItem(const QString & s) {
		QByteArray data = escapedUtf8(s);
		fprintf(fd, "<li>%s</li>\n", data.constData());
	}

	void beginSwitch() {
		fprintf(fd, "<table>\n");
	}

	void cswitch(const ArgHandler * h) {
		QByteArray longName = escapedUtf8(h->longName);
		fprintf(fd, "<tr><td class=\"short\">");
		if (h->shortSwitch)
			fprintf(fd, "-%c,",h->shortSwitch);
		fprintf(fd, "</td><td class=\"long\">--%s%s</td><td class=\"arg\">", longName.constData(),
				(h->qthack?"<span style=\"font-weight: normal; font-size: 80%; color:red;\">*</span>":""));
		for (int i = 0; i < h->argn.size(); ++i) {
			QByteArray argData = escapedUtf8(h->argn.at(i));
			fprintf(fd, "&lt;%s&gt; ",argData.constData());
		}
		QByteArray desc = escapedUtf8(h->getDesc());
		fprintf(fd, "</td><td class=\"desc\">%s</td></tr>\n",desc.constData());
	}

	void endSwitch() {
		fprintf(fd, "</table>\n");
		fprintf(fd, "<p>Items marked <span style=\"font-weight: normal; font-size: 80%%; color:red;\">*</span> are only available using a patched Qt.</p>");
	}

};

/*!
  Create a Html outputter
  \param fd A file description to output to
*/
  Outputter * Outputter::html(FILE * fd) {
	return new HtmlOutputter(fd);
}
