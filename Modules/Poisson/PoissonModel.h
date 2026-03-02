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
 * \file PoissonModel.h
 * \brief tiberCAD poisson module header.
 *
 * \note This file is part of module poisson.
 */


#ifndef TC_POISSONMODEL_H
#define TC_POISSONMODEL_H

#include "tibercad/physics/PhysicalModel.h"

#include "libmesh/point.h"
#include "libmesh/tensor_value.h"
#include "libmesh/vector_value.h"


class PolarizationModel;
class ChargeDensityModel;
class PermittivityModel;
class Elem;


//! This is the base class for the Poisson physical model
class PoissonModel : public PhysicalModel
{

  public:

    //! Destructor
    virtual ~PoissonModel(void) {};

    //! Creator function
    static PoissonModel* create(const Material* mat, const ModelOptions& options);


    //! Get the relative permittivity
    const libMesh::RealTensor& get_permittivity(void) const;


    //! Get the total polarization
    const libMesh::RealVectorValue& get_polarization(void) const;


    //! Get the total charge
    double get_charge_density(void) const;


    //! Set the relative permittivity
    libMesh::RealTensor& get_permittivity(void);


    //! Set the total polarization
    libMesh::RealVectorValue& get_polarization(void);


    //! Set the total charge
    void set_charge_density(double charge_density);

    //! Reinit for element \c elem
    void set_element(const Elem* elem);


    //! Set the current point
    void set_point(const Point& point);


    //! Calculate everything
    void calculate(void);


  protected:

    //! Constructor
    PoissonModel(const ModelOptions& options);

    virtual void do_init(void) override;

    virtual void prepare_submodels(void) override;

    //! do the actual calculation
    virtual void do_calculate(void);

    const Elem* get_element(void) const { return _elem; }
  
    const Point& get_point(void) const { return _point; }
  

  private:


    //! The polarization models
    std::vector<PolarizationModel* > _pm;

    //! The element we are currently working on
    const Elem* _elem;

    //! The point we are currently using
    Point _point;

    //! The relative permittivity
    libMesh::RealTensor _permittivity;

    //! The polarization
    libMesh::RealVectorValue _polarization;

    //! The charge density
    double _charge_density;

    //! The permittivity model
    PermittivityModel* _permittivity_model;

    //! The charge density model
    ChargeDensityModel* _charge_density_model;

    //! The constructor method
    static TiberModelObject* _create(const ModelOptions& options);

    //! The destructor method
    static void _destroy(TiberModelObject* p);

};




inline
PoissonModel::PoissonModel(const ModelOptions& options) :
  PhysicalModel(options),
  _charge_density_model(NULL),
  _permittivity_model(NULL)
{
}



inline
void
PoissonModel::set_element(const Elem* elem)
{
  _elem = elem;
}


inline
void
PoissonModel::set_point(const Point& point)
{
  _point = point;
}


inline
const libMesh::RealTensor&
PoissonModel::get_permittivity(void) const
{
  return _permittivity;
}

inline
libMesh::RealTensor&
PoissonModel::get_permittivity(void)
{
  return _permittivity;
}


inline
libMesh::RealVectorValue&
PoissonModel::get_polarization(void)
{
  return _polarization;
}


inline
const libMesh::RealVectorValue&
PoissonModel::get_polarization(void) const
{
  return _polarization;
}


inline
double
PoissonModel::get_charge_density(void) const
{
  return _charge_density;
}

inline
void
PoissonModel::set_charge_density(double charge_density)
{
  _charge_density = charge_density;
}


inline
void
PoissonModel::calculate(void)
{
  do_calculate();
}

#endif // TC_POISSONMODEL_H
