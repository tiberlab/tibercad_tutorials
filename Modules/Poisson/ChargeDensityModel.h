/*  
 * This file is part of the tiberCAD module poisson.
 *
 * tiberCAD modules are licensed under the GNU General Public License v3.
 *
 * tiberCAD is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * tiberCAD is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with tiberCAD. If not, see <http://www.gnu.org/licenses/>.
 */

/*!
 * \file ChargeDensityModel.h
 * \brief tiberCAD poisson module header.
 *
 * \note This file is part of module poisson.
 */


#ifndef TC_CHARGEDENSITYMODEL_H
#define TC_CHARGEDENSITYMODEL_H

#include "tibercad/physics/PhysicalModel.h"


class Elem;
class Point;

// Base class for charge density models
class ChargeDensityModel : public PhysicalModel
{

  public:

    virtual ~ChargeDensityModel(void) {};

    double get_charge_density(const Elem* elem, const Point&);


  protected:

    ChargeDensityModel(const ModelOptions& options);

    virtual double calculate_charge_density(const Elem* elem, const Point& point) = 0;

};


ChargeDensityModel::ChargeDensityModel(const ModelOptions& options) :
  PhysicalModel(options)
{
}


double
ChargeDensityModel::get_charge_density(const Elem* elem, const Point& point)
{
  return calculate_charge_density(elem, point);
}


#endif // TC_CHARGEDENSITYMODEL_H
