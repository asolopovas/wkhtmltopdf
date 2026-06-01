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
#include <QStringList>

class ManOutputter: public Outputter {
private:
	FILE * fd;
	int order;

	QByteArray utf8(const QString & value) const {
		return value.toUtf8();
	}

	void writeString(const QString & value) {
		QByteArray data = utf8(value);
		fprintf(fd, "%s", data.constData());
	}

	QString escaped(const QString & value) const {
		return QString(value).replace("-", "\\-");
	}

public:
	ManOutputter(FILE * _): fd(_) {
		fprintf(fd,".TH WKHTMLTOPDF 1 \"2009 February 23\"\n\n");
	}

	void beginSection(const QString & name) {
		QByteArray title = utf8(name.toUpper());
		fprintf(fd, ".SH %s\n", title.constData());
	}

	void endSection() {
		fprintf(fd, "\n");
	}

	void beginParagraph() {
	}

	void endParagraph() {
		fprintf(fd, "\n\n");
	}

	void text(const QString & t) {
		writeString(escaped(t));
	}

	void sectionLink(const QString & t) {
		text(t);
	}

	void bold(const QString & t) {
		QByteArray data = utf8(t);
		fprintf(fd, "\\fB%s\\fP", data.constData());
	}

	void italic(const QString & t) {
		QByteArray data = utf8(t);
		fprintf(fd, "\\fB%s\\fP", data.constData());
	}

	void link(const QString & t) {
		QByteArray data = utf8(t);
		fprintf(fd, "<%s>", data.constData());
	}

	void verbatim(const QString & t) {
		QStringList l = escaped(t).split('\n');
		while (!l.isEmpty() && l.back() == "") l.pop_back();
		for (int i = 0; i < l.size(); ++i) {
			fprintf(fd, "  ");
			writeString(l.at(i));
			fprintf(fd, "\n");
		}
		fprintf(fd, "\n");
	}

	void beginSwitch() {
		fprintf(fd, ".PD 0\n");
	}

	void beginList(bool ordered) {
		order=(ordered?1:-1);
	}

	void endList() {
		fprintf(fd, "\n");
	}

	void listItem(const QString & s) {
		if (order < 0) fprintf(fd, " * ");
		else fprintf(fd, "%3d ", order++);
		writeString(s);
		fprintf(fd,"\n");
	}

	void cswitch(const ArgHandler * h) {
		fprintf(fd, ".TP\n");
		fprintf(fd, "\\fB");
		if (h->shortSwitch != 0)
			fprintf(fd, "\\-%c, ", h->shortSwitch);
		else
			fprintf(fd, "    ");
		QByteArray longName = utf8(h->longName);
		fprintf(fd,"\\-\\-%s\\fR", longName.constData());

		for (QVector<QString>::const_iterator i = h->argn.constBegin(); i != h->argn.constEnd(); ++i) {
			QByteArray arg = utf8(*i);
			fprintf(fd," \\fI<%s>\\fR", arg.constData());
		}

		QByteArray desc = utf8(escaped(h->desc));
		fprintf(fd, "\n%s\n", desc.constData());
	}

	void endSwitch() {
		fprintf(fd, ".PD\n");
		fprintf(fd, "\n");
	}
};

/*!
  Create a man page outputter
  \param fd A file description to output to
*/
Outputter * Outputter::man(FILE * fd) {
  return new ManOutputter(fd);
}
