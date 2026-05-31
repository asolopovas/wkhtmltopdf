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


#include "outline_p.hh"
#include "pdfsettings.hh"
#include <QTextStream>

namespace wkhtmltopdf {

void dumpDefaultTOCStyleSheet(QTextStream & stream, settings::TableOfContent & s) {
    stream << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" << '\n'
		   << "<xsl:stylesheet version=\"2.0\"" << '\n'
		   << "                xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\"" << '\n'
		   << "                xmlns:outline=\"http://wkhtmltopdf.org/outline\"" << '\n'
		   << "                xmlns=\"http://www.w3.org/1999/xhtml\">" << '\n'
		   << "  <xsl:output doctype-public=\"-//W3C//DTD XHTML 1.0 Strict//EN\"" << '\n'
	       << "              doctype-system=\"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"" << '\n'
		   << "              indent=\"yes\" />" << '\n'
		   << "  <xsl:template match=\"outline:outline\">" << '\n'
		   << "    <html>" << '\n'
		   << "      <head>" << '\n'
		   << "        <title>" << s.captionText << "</title>" << '\n'
		   << "        <meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />" << '\n'
		   << "        <style>" << '\n'
		   << "          h1 {" << '\n'
		   << "            text-align: center;" << '\n'
		   << "            font-size: 20px;" << '\n'
		   << "            font-family: arial;" << '\n'
		   << "          }" << '\n';
	if (s.useDottedLines)
		stream << "          div {border-bottom: 1px dashed rgb(200,200,200);}" << '\n';
	stream << "          span {float: right;}" << '\n'
		   << "          li {list-style: none;}" << '\n'
		   << "          ul {" << '\n'
		   << "            font-size: 20px;" << '\n'
		   << "            font-family: arial;" << '\n'
		   << "          }" << '\n'
		   << "          ul ul {font-size: " << (s.fontScale*100.0) << "%; }" << '\n'
		   << "          ul {padding-left: 0em;}" << '\n'
		   << "          ul ul {padding-left: " << s.indentation << ";}" << '\n'
		   << "          a {text-decoration:none; color: black;}" << '\n'
		   << "        </style>" << '\n'
		   << "      </head>" << '\n'
		   << "      <body>" << '\n'
		   << "        <h1>" << s.captionText << "</h1>" << '\n'
		   << "        <ul><xsl:apply-templates select=\"outline:item/outline:item\"/></ul>" << '\n'
		   << "      </body>" << '\n'
		   << "    </html>" << '\n'
		   << "  </xsl:template>" << '\n'
		   << "  <xsl:template match=\"outline:item\">" << '\n'
		   << "    <li>" << '\n'
		   << "      <xsl:if test=\"@title!=''\">" << '\n'
		   << "        <div>" << '\n'
		   << "          <a>" << '\n';
	if (s.forwardLinks)
		stream << "            <xsl:if test=\"@link\">" << '\n'
			   << "              <xsl:attribute name=\"href\"><xsl:value-of select=\"@link\"/></xsl:attribute>" << '\n'
			   << "            </xsl:if>" << '\n';
	stream << "            <xsl:if test=\"@backLink\">" << '\n'
		   << "              <xsl:attribute name=\"name\"><xsl:value-of select=\"@backLink\"/></xsl:attribute>" << '\n'
		   << "            </xsl:if>" << '\n'
		   << "            <xsl:value-of select=\"@title\" /> " << '\n'
		   << "          </a>" << '\n'
		   << "          <span> <xsl:value-of select=\"@page\" /> </span>" << '\n'
		   << "        </div>" << '\n'
		   << "      </xsl:if>" << '\n'
		   << "      <ul>" << '\n'
		   << "        <xsl:comment>added to prevent self-closing tags in QtXmlPatterns</xsl:comment>" << '\n'
		   << "        <xsl:apply-templates select=\"outline:item\"/>" << '\n'
		   << "      </ul>" << '\n'
		   << "    </li>" << '\n'
		   << "  </xsl:template>" << '\n'
		   << "</xsl:stylesheet>" << '\n';
}

}
